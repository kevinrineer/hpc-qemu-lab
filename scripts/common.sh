#!/usr/bin/env bash
set -e

### CONFIG
ARCH=$(uname -m)
BRIDGE_IF="br0"
QCOW_DIR="$(dirname "$0")/../qcow2"
ROCKY_VERSION="${1:-10.0}"
IMAGE_DIR="$DISK_DIR/images"
DISK_PATH="$DISK_DIR/${VM_NAME}.qcow2"
SEED_ISO="$DISK_DIR/${VM_NAME}-seed.iso"
TAP_IF="tap0"

==> download_qcow2.sh <==
#!/usr/bin/env bash
set -euo pipefail

# Config
