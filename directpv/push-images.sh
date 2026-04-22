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
    push_image "quay.io/minio/livenessprobe:v2.18.0-0" # quay.io/minio/livenessprobe@sha256:af8bac7b24bbfcc064e58d45c1c2ebaf75b9ac71315a604e0870100fa6aed8da
    push_image "quay.io/minio/csi-node-driver-registrar:v2.16.0-0" # quay.io/minio/csi-node-driver-registrar@sha256:183b3ac969d133457595fa2abfd9d81d20e83a6bc4606375662d036f56462dde
    push_image "quay.io/minio/csi-provisioner:v6.2.0-0" # quay.io/minio/csi-provisioner@sha256:f83e880ce4290b1ef4fa15a588138eafecdb40106208a5295c0b24d03cbaddbd
    push_image "quay.io/minio/csi-resizer:v2.1.0-0" # quay.io/minio/csi-resizer@sha256:cb338f5c5a9f781f289b6f25fedebbeeb4eec9fda2aeb2c0a1eaa8529c4c9738
    push_image "quay.io/minio/directpv:v5.1.2" # quay.io/minio/directpv@sha256:1add60387c6714470907ef109711042947959de6bc80ddd02107e76fa79abaa2
}

init "$@"
main "$@"
