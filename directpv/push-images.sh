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
# This script pushes DirectPV and its sidecar images to private registry.
#

set -o errexit
set -o nounset
set -o pipefail

declare registry

function init() {
    if [ "$#" -ne 1 ]; then
        cat <<EOF
USAGE:
  push-images.sh <REGISTRY>

ARGUMENT:
<REGISTRY>    Image registry without scheme prefix like 'http', 'docker' etc.

EXAMPLE:
$ push-images.sh registry.airgap.net/aistor
EOF
        exit 255
    fi
    registry="$1"

    if ! which skopeo >/dev/null 2>&1; then
        echo "skopeo not found; please install"
        exit 255
    fi
}

# usage: push_image <image>
function push_image() {
    image="$1"
    private_image="${image/quay.io\/minio/$registry}"
    echo "Pushing image ${image}"
    skopeo copy --multi-arch=all --preserve-digests "docker://${image}" "docker://${private_image}"
}

function main() {
    push_image "quay.io/minio/livenessprobe:v2.19.0-0" # quay.io/minio/livenessprobe@sha256:471eff92da0a2112417919f18e5636897fe4adb05d3160134e9124e97fc84e4f
    push_image "quay.io/minio/csi-node-driver-registrar:v2.17.0-0" # quay.io/minio/csi-node-driver-registrar@sha256:9188486550743b7f1f8b387ec60e81ada54fc2cdf03e9f27682dcb99f8d0dece
    push_image "quay.io/minio/csi-provisioner:v6.3.0-0" # quay.io/minio/csi-provisioner@sha256:8c4b1729a67156f6fa9483b580046e44cdf86665c5b17ccd8779666b27572516
    push_image "quay.io/minio/csi-resizer:v2.2.1-0" # quay.io/minio/csi-resizer@sha256:f42beff6500aab8d239fd2c0e4c43db98320a51e10fe1c8728b5014744a23f0f
    push_image "quay.io/minio/directpv:v5.1.3" # quay.io/minio/directpv@sha256:dfce1cb76d6d4d0e3e74eb78b151727223b0651f143863cc8a73663b23bc02fb
}

init "$@"
main "$@"
