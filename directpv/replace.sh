#!/usr/bin/env bash
#
# MinIO, Inc. CONFIDENTIAL
#
# [2014] - [2025] MinIO, Inc. All Rights Reserved.
#
# NOTICE:  All information contained herein is, and remains the property
# of MinIO, Inc and its suppliers, if any.  The intellectual and technical
# concepts contained herein are proprietary to MinIO, Inc and its suppliers
# and may be covered by U.S. and Foreign Patents, patents in process, and are
# protected by trade secret or copyright law. Dissemination of this information
# or reproduction of this material is strictly forbidden unless prior written
# permission is obtained from MinIO, Inc.

#
# Replace a DirectPV drive with another drive on the same node.
#
# Run with no arguments to automatically replace every 'Lost' drive in the cluster
# with a suitable empty drive on the same node. Alternatively, pass
# <SRC-DRIVE> <DEST-DRIVE> [NODE] to replace a specific drive. Run with -h for details.
#

set -e -o pipefail

# Run the last command of a pipeline in the current shell so that a `... | while`
# loop can populate global variables (see build_drive_map).
shopt -s lastpipe

ME=$(basename "$0"); export ME

export drive_id=""

# Drive metadata maps keyed by drive ID, populated once by build_drive_map.
declare -A drive_name_map
declare -A drive_node_map
declare -A drive_status_map
declare -A drive_allocated_map
declare -A drive_total_map
declare -A node_map
all_drive_ids=()

function usage() {
    cat <<EOF
NAME:
  ${ME} - Replace a DirectPV drive with another drive on the same node.

DESCRIPTION:
  All volumes are moved from the source drive to the destination drive on the same
  node, the pods using those volumes are restarted, and the source drive is replaced.
  The script runs in one of two modes:

  Automatic mode (no arguments):
    Scan every node for 'Lost' drives and replace each one with a suitable empty
    drive (a 'Ready' drive with no volumes) on the same node. For each lost drive,
    the replacement is chosen by:
      1. an empty drive whose total capacity equals the lost drive's total capacity;
      2. otherwise, an empty drive whose total capacity is at least the lost drive's
         used (allocated) capacity.
    If more than one empty drive qualifies, the candidates are listed and you choose
    one. Otherwise the only candidate is auto-picked and you are asked to confirm.

  Manual mode (with arguments):
    Replace a specific source drive with a specific destination drive. Both drives
    must exist on the same node.

USAGE:
  ${ME}
  ${ME} <SRC-DRIVE> <DEST-DRIVE> [NODE]

ARGUMENTS:
  SRC-DRIVE   Source drive to replace, given by device name (e.g. /dev/sdb) or drive ID.
  DEST-DRIVE  Destination drive to replace it with, given by device name or drive ID.
  NODE        Node name. Required only when SRC-DRIVE or DEST-DRIVE is a device name,
              since device names are not unique across nodes. Not needed when both
              arguments are drive IDs.

OPTIONS:
  -h, --help  Show this help and exit.

EXAMPLES:
  # Automatic mode: scan all nodes and replace every lost drive with a matching empty drive.
  $ ${ME}

  # Manual mode: replace /dev/sdb with /dev/sdc on node worker4.
  $ ${ME} /dev/sdb /dev/sdc worker4

  # Manual mode using drive IDs (NODE is not required):
  # replace lost drive 1bff96ba-f32e-4493-b95b-897c07d68460 with new drive
  # 52bf469b-e62e-40b8-a23e-941cd7fe03b3.
  $ ${ME} 1bff96ba-f32e-4493-b95b-897c07d68460 52bf469b-e62e-40b8-a23e-941cd7fe03b3
EOF
}

function init() {
    if [ "${1}" == "-h" ] || [ "${1}" == "--help" ]; then
        usage
        exit 0
    fi

    if [ "$#" -ne 0 ] && [[ $# -lt 2 || $# -gt 3 ]]; then
        usage
        exit 255
    fi

    if ! which kubectl >/dev/null 2>&1; then
        echo "❌ kubectl not found; please install it and retry"
        exit 255
    fi

    if ! kubectl directpv --version >/dev/null 2>&1; then
        echo "❌ kubectl directpv plugin not found; please install it and retry"
        exit 255
    fi
}

# usage: get_volumes <drive-id>
function get_volumes() {
    kubectl get directpvvolumes \
            --selector="directpv.min.io/drive=${1}" \
            -o go-template='{{range .items}}{{.metadata.name}}{{ " " | print }}{{end}}'
}

# usage: get_pod_name <volume-id>
function get_pod_name() {
    # shellcheck disable=SC2016
    kubectl get directpvvolumes "${1}" \
            -o go-template='{{range $k,$v := .metadata.labels}}{{if eq $k "directpv.min.io/pod.name"}}{{$v}}{{end}}{{end}}'
}

# usage: get_pod_namespace <volume-id>
function get_pod_namespace() {
    # shellcheck disable=SC2016
    kubectl get directpvvolumes "${1}" \
            -o go-template='{{range $k,$v := .metadata.labels}}{{if eq $k "directpv.min.io/pod.namespace"}}{{$v}}{{end}}{{end}}'
}

# build_drive_map populates the drive metadata maps (keyed by drive ID) with a
# single API call, so the no-arg scan need not query each drive repeatedly.
function build_drive_map() {
    local id name node status allocated total

    # shellcheck disable=SC2016
    kubectl get directpvdrives -o go-template='{{range .items}}{{.metadata.name}}|{{index .metadata.labels "directpv.min.io/drive-name"}}|{{index .metadata.labels "directpv.min.io/node"}}|{{.status.status}}|{{.status.allocatedCapacity}}|{{.status.totalCapacity}}{{"\n"}}{{end}}' |
        while IFS='|' read -r id name node status allocated total; do
            if [ -z "${id}" ]; then
                continue
            fi
            drive_name_map["${id}"]="${name}"
            drive_node_map["${id}"]="${node}"
            drive_status_map["${id}"]="${status}"
            drive_allocated_map["${id}"]="${allocated}"
            drive_total_map["${id}"]="${total}"
            all_drive_ids+=( "${id}" )
            if [ -n "${node}" ]; then
                node_map["${node}"]=true
            fi
        done
}

# confirm_replacement displays the source and destination drive properties and
# returns success only if the user confirms. Used for auto-picked drives.
function confirm_replacement() {
    echo

    echo '!!' "Replacing drive ${src_drive_id}/${drive_name_map[$src_drive_id]:-unknown} with drive ${dest_drive_id}/${drive_name_map[$dest_drive_id]:-unknown} on node ${src_node}:"
    if ! kubectl directpv list drives "${src_drive_id}" "${dest_drive_id}"; then
        echo "❌ unable to list drives ${src_drive_id} and ${dest_drive_id}"
        exit 1
    fi

    read -r -p "💡 Confirm? [y/N] " reply || reply=""
    case "${reply}" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# usage: do_replace <src-drive-id> <dest-drive-id> <node>
function do_replace() {
    local src_drive_id="${1}"
    local dest_drive_id="${2}"
    local src_node="${3}"

    # Cordon source and destination drives
    if ! kubectl directpv cordon "${src_drive_id}" "${dest_drive_id}"; then
        echo "❌ unable to cordon drives ${src_drive_id} and ${dest_drive_id}"
        exit 1
    fi

    # Cordon kubernetes node
    if ! kubectl cordon "${src_node}"; then
        echo "❌ unable to cordon node ${src_node}"
        exit 1
    fi

    # shellcheck disable=SC2207
    volumes=( $(get_volumes "${src_drive_id}") )
    for volume in "${volumes[@]}"; do
        pod_name=$(get_pod_name "${volume}")
        pod_namespace=$(get_pod_namespace "${volume}")

        if ! kubectl delete pod "${pod_name}" --namespace "${pod_namespace}"; then
            echo "❌ unable to delete pod '${pod_name}' using volume '${volume}'; please delete the pod manually"
        fi
    done

    if [ "${#volumes[@]}" -gt 0 ]; then
        # Wait for associated DirectPV volumes to be unbound
        while kubectl directpv list volumes --no-headers "${volumes[@]}" | grep -q Bounded; do
            echo '!!' "...waiting for volumes to be unbound"
            sleep 10
        done
    else
        echo "💡 no volumes found in source drive ${src_drive_id} on node ${src_node}"
    fi

    # Run move command
    kubectl directpv move "${src_drive_id}" "${dest_drive_id}"

    # Uncordon destination drive
    kubectl directpv uncordon "${dest_drive_id}"

    # Uncordon kubernetes node
    kubectl uncordon "${src_node}"

    echo "✅ replaced drive ${src_drive_id} with drive ${dest_drive_id} on node ${src_node}"
}

# usage: select_empty_drive <lost-id> <candidate-empty-id>...
# Picks a replacement empty drive for the given lost drive and sets the global
# `selected_empty` (empty string if none suitable). Selection order:
#   (a) empty drives whose total capacity equals the lost drive's total capacity;
#   (b) otherwise, empty drives whose total capacity is >= the lost drive's used
#       (allocated) capacity;
#   (c) if more than one candidate remains, list them and ask the user to choose.
function select_empty_drive() {
    local lost_id="${1}"; shift
    local lost_total="${drive_total_map[$lost_id]}"
    local lost_used="${drive_allocated_map[$lost_id]}"
    local cand choice candidates=()

    selected_empty=""
    selected_by_user=false

    # Step (a): empty drives with the same total capacity as the lost drive.
    for cand in "$@"; do
        if [ -n "${drive_total_map[$cand]}" ] && [ "${drive_total_map[$cand]}" == "${lost_total}" ]; then
            candidates+=( "${cand}" )
        fi
    done

    # Step (b): otherwise, empty drives large enough for the lost drive's used capacity.
    if [ "${#candidates[@]}" -eq 0 ]; then
        for cand in "$@"; do
            if [ -n "${drive_total_map[$cand]}" ] && [ "${drive_total_map[$cand]}" -ge "${lost_used:-0}" ]; then
                candidates+=( "${cand}" )
            fi
        done
    fi

    if [ "${#candidates[@]}" -eq 0 ]; then
        return 0
    fi
    if [ "${#candidates[@]}" -eq 1 ]; then
        selected_empty="${candidates[0]}"
        return 0
    fi

    # Step (c): multiple candidates; show them and let the user choose.
    echo
    echo '!!' "Multiple empty drives can replace lost drive ${lost_id}/${drive_name_map[$lost_id]:-unknown} on node ${drive_node_map[$lost_id]}:"
    if ! kubectl directpv list drives "${candidates[@]}"; then
        echo "❌ unable to list candidate drives"
        exit 1
    fi

    while true; do
        read -r -p "💡 Enter the drive ID to use as the replacement (or press Enter to skip): " choice || choice=""
        if [ -z "${choice}" ]; then
            return 0
        fi
        for cand in "${candidates[@]}"; do
            if [ "${choice}" == "${cand}" ]; then
                selected_empty="${cand}"
                selected_by_user=true
                return 0
            fi
        done
        echo "❌ invalid drive ID '${choice}'; please choose one of the listed drive IDs"
    done
}

# usage: replace_all <node>
function replace_all() {
    local node="${1}"
    local did lost_id i
    local lost_ids=() empty_ids=()

    # Gather 'Lost' drives and empty 'Ready' candidates on this node from the map.
    for did in "${all_drive_ids[@]}"; do
        if [ "${drive_node_map[$did]}" != "${node}" ]; then
            continue
        fi
        case "${drive_status_map[$did]}" in
            Lost)
                lost_ids+=( "${did}" )
                ;;
            Ready)
                if [ "${drive_allocated_map[$did]}" == "0" ]; then
                    empty_ids+=( "${did}" )
                fi
                ;;
        esac
    done

    if [ "${#lost_ids[@]}" -eq 0 ]; then
        echo '!!' "No lost drive found on node ${node}"
        return 0
    fi

    for lost_id in "${lost_ids[@]}"; do
        # Pick a replacement from the remaining empty drives (sparse array expands
        # to existing elements only).
        select_empty_drive "${lost_id}" "${empty_ids[@]}"

        if [ -z "${selected_empty}" ]; then
            echo "❌ skipping lost drive ${lost_id}/${drive_name_map[$lost_id]:-unknown} on node ${node}; no suitable empty drive found"
            continue
        fi

        # Remove the chosen empty drive from the pool so it is not reused.
        for i in "${!empty_ids[@]}"; do
            if [ "${empty_ids[$i]}" == "${selected_empty}" ]; then
                unset 'empty_ids[i]'
                break
            fi
        done

        src_drive_id="${lost_id}"
        dest_drive_id="${selected_empty}"
        src_node="${node}"

        # A user-chosen drive (step (c)) is already an explicit confirmation.
        if [ "${selected_by_user}" == "true" ] || confirm_replacement; then
            do_replace "${src_drive_id}" "${dest_drive_id}" "${src_node}"

            # do_replace succeeded; offer to remove the replaced (source) drive.
            read -r -p "💡 Remove replaced drive ${src_drive_id}/${drive_name_map[$src_drive_id]:-unknown} from DirectPV? [y/N] " reply || reply=""
            case "${reply}" in
                [yY]|[yY][eE][sS])
                    if kubectl directpv remove "${src_drive_id}"; then
                        echo "✅ removed drive ${src_drive_id} from DirectPV"
                    else
                        echo "❌ unable to remove drive ${src_drive_id} from DirectPV"
                    fi
                    ;;
            esac
        else
            echo "❌ skipped replacement of lost drive ${lost_id}/${drive_name_map[$lost_id]:-unknown}"
        fi
    done
}

function main_no_args() {
    build_drive_map

    if [ "${#node_map[@]}" -eq 0 ]; then
        echo '!!' "no drive added into DirectPV"
        exit 0
    fi

    for node in "${!node_map[@]}"; do
        replace_all "${node}"
    done
}

# usage: is_uuid <value>
function is_uuid() {
    [[ "$1" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
}

# usage: get_drive_ids <node> <drive-name>
function get_drive_ids() {
    kubectl get directpvdrives \
            --selector="directpv.min.io/node==${1},directpv.min.io/drive-name==${2}" \
            -o go-template='{{range .items}}{{.metadata.name}} {{end}}'
}

# usage: must_get_drive_id <node> <drive-name>
function must_get_drive_id() {
    if [ -z "${1}" ]; then
        echo "❌ node argument must be provided for drive name"
        exit 255
    fi
    # shellcheck disable=SC2207
    drive_ids=( $(get_drive_ids "${1}" "${2}") )
    if [ "${#drive_ids[@]}" -eq 0 ]; then
        echo "❌ drive $2 on node $1 not found"
        exit 255
    fi
    if [ "${#drive_ids[@]}" -gt 1 ]; then
        echo "❌ duplicate drive ids found for $2"
        exit 255
    fi
    drive_id="${drive_ids[0]}"
}

# usage: get_node_name <drive-id>
function get_node_name() {
    # shellcheck disable=SC2016
    kubectl get directpvdrives "${1}" \
            -o go-template='{{range $k,$v := .metadata.labels}}{{if eq $k "directpv.min.io/node"}}{{$v}}{{end}}{{end}}'
}

function main_args() {
    src_drive="${1#/dev/}"
    dest_drive="${2#/dev/}"
    node="${3}"

    if [ "${src_drive}" == "${dest_drive}" ]; then
        echo "❌ source and destination drives are the same"
        exit 255
    fi

    if ! is_uuid "${src_drive}"; then
        must_get_drive_id "${node}" "${src_drive}"
        src_drive_id="${drive_id}"
    else
        src_drive_id="${src_drive}"
    fi

    if ! is_uuid "${dest_drive}"; then
        must_get_drive_id "${node}" "${dest_drive}"
        dest_drive_id="${drive_id}"
    else
        dest_drive_id="${dest_drive}"
    fi

    if [ "${src_drive_id}" == "${dest_drive_id}" ]; then
        echo "❌ source and destination drives resolve to the same drive ID"
        exit 1
    fi

    src_node=$(get_node_name "${src_drive_id}")
    if [ -z "${src_node}" ]; then
        echo "❌ unable to find the node name of the source drive ${src_drive}"
        exit 1
    fi

    dest_node=$(get_node_name "${dest_drive_id}")
    if [ -z "${dest_node}" ]; then
        echo "❌ unable to find the node name of the destination drive ${dest_drive}"
        exit 1
    fi

    if [ "${src_node}" != "${dest_node}" ]; then
        echo "❌ source and destination drives are on different nodes; both must be on the same node"
        exit 1
    fi

    do_replace "${src_drive_id}" "${dest_drive_id}" "${src_node}"
}

function main() {
    if [ "$#" -eq 0 ]; then
        main_no_args
    else
        main_args "$@"
    fi
}

init "$@"
main "$@"
