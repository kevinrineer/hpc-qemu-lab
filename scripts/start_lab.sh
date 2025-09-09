#!/usr/bin/env bash
set -euo pipefail

ISO_DIR="$(dirname "$0")/../iso"
IMG_DIR="$(dirname "$0")/../images"
ISO_PATH=$(find "$ISO_DIR" -name '*.iso' | head -n1)

if [ ! -f "$ISO_PATH" ]; then
    echo "ISO not found. Run download_iso.sh first."
    exit 1
fi

mkdir -p "$IMG_DIR"

# VM definitions
VMS=(central-it head login compute1 compute2)
RAM_MB=2048
CPU=2
DISK_SIZE_GB=10

for VM in "${VMS[@]}"; do
    IMG="${IMG_DIR}/${VM}.qcow2"
    if [ ! -f "$IMG" ]; then
        echo "Creating disk for $VM..."
        qemu-img create -f qcow2 "$IMG" "${DISK_SIZE_GB}G"
    fi
done

# Launch VMs
for VM in "${VMS[@]}"; do
    echo "Launching $VM..."
    qemu-system-$(uname -m) \
        -m "$RAM_MB" \
        -smp "$CPU" \
        -drive file="${IMG_DIR}/${VM}.qcow2",format=qcow2 \
        -cdrom "$ISO_PATH" \
        -boot order=d \
        -netdev user,id=net0,hostfwd=tcp::22${RANDOM:0:2}-:22 \
        -device virtio-net-pci,netdev=net0 \
        -name "$VM" \
        -display none \
        -daemonize
done

echo "All VMs launched in background. SSH access via host ports 2200+, see QEMU port forwards."

