#!/usr/bin/env bash
set -e

# ==== Config ====
TAP_IF="tap0"
MEMORY="2048"
CPU="2"
VM_NAMES=("node1" "node2" "node3")
DEFAULT_IMAGE_DIR="$HOME/vms"
QEMU_BIN="qemu-system-x86_64"
TMUX_SESSION="vms"

IMAGE_DIR="$DEFAULT_IMAGE_DIR"

# ==== Functions ====

start_vm() {
	local name="$1"
	local disk_img="$IMAGE_DIR/${name}.qcow2"

	if tmux list-windows -t "$TMUX_SESSION" 2>/dev/null | grep -q "^$name"; then
		echo "VM $name already has a window in tmux session $TMUX_SESSION."
		return
	fi

	echo "Starting VM: $name"

	local cmd="$QEMU_BIN -enable-kvm \
        -m $MEMORY \
        -smp $CPU \
        -nographic \
        -netdev tap,id=net0,ifname=$TAP_IF,script=no,downscript=no \
        -device e1000,netdev=net0 \
        -boot n"

	if [[ -f "$disk_img" ]]; then
		echo "Using disk image: $disk_img"
		cmd="$cmd -drive file=$disk_img,if=virtio"
	else
		echo "No disk image found for $name — booting PXE-only"
	fi

	tmux new-window -t "$TMUX_SESSION" -n "$name" "$cmd"
}

stop_vm() {
	local name="$1"

	if tmux list-windows -t "$TMUX_SESSION" 2>/dev/null | grep -q "^$name"; then
		echo "Stopping VM: $name"
		tmux send-keys -t "$TMUX_SESSION:$name" C-c
		sleep 1
		tmux kill-window -t "$TMUX_SESSION:$name"
	else
		echo "VM $name is not running (no tmux window found)."
	fi
}

restart_vm() {
	stop_vm "$1"
	sleep 1
	start_vm "$1"
}

usage() {
	echo "Usage: $0 {start|stop|restart} [-a|--all | vm1,vm2,...] [--image-path /path/to/images]"
	exit 1
}

# ==== Parse Args ====
ACTION="$1"
shift || true

TARGETS=()
while [[ $# -gt 0 ]]; do
	case "$1" in
	-a | --all)
		TARGETS=("${VM_NAMES[@]}")
		shift
		;;
	--image-path)
		IMAGE_DIR="$2"
		shift 2
		;;
	*)
		if [[ -z "$ACTION" ]]; then usage; fi
		IFS=',' read -ra TARGETS <<<"$1"
		shift
		;;
	esac
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
	usage
fi

# ==== Ensure tmux session ====
if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
	echo "Creating tmux session: $TMUX_SESSION"
	tmux new-session -d -s "$TMUX_SESSION" -n placeholder "echo 'VM Session: Press Ctrl+b w to switch between VMs'; bash"
	tmux kill-window -t "$TMUX_SESSION:placeholder"
fi

# ==== Execute ====
for vm in "${TARGETS[@]}"; do
	case "$ACTION" in
	start) start_vm "$vm" ;;
	stop) stop_vm "$vm" ;;
	restart) restart_vm "$vm" ;;
	*) usage ;;
	esac
done

echo "Done. To attach: tmux attach -t $TMUX_SESSION"
