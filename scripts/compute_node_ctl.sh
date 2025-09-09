#!/usr/bin/env bash
set -e

### CONFIG
VM_DIR="$HOME/vms/compute"
BRIDGE_IF="br0"
MEMORY="1024"
CPU="1"
DEFAULT_IMAGE="/dev/null" # Warewulf compute nodes boot via PXE, so this is dummy
PXE_ROM="pxe-rtl8139.rom" # Typically built into QEMU

### HELPER FUNCTIONS

usage() {
	echo "Usage: '$(basename $0)' [start|stop|restart] [-i|--image-path PATH] [-a|--all] [HOSTNAME1,HOSTNAME2,...] "
	exit 1
}

get_opts() {

	echo "in getopts"

	TEMP=$(getopt --options "a,h,i:" --longoptions "all,help,image-path:" --name "$0" -- "$@")

	eval set -- "$TEMP"

	ALL=false

	while [[ "$#" -gt 0 ]]; do
		case "$1" in
		-a | --all)
			all=true
			shift
			;;
		-i | --image-path)
			image_path="$2"
			if [[ -z "$image_path" ]]; then
				echo "Didn't find anything at provided path"
				exit 1
			fi
			shift 2
			;;
		-h | --help)
			usage
			;;
		:)
			echo -e "option requires an argument.\n"
			usage
			exit 1
			;;
		?)
			echo -e "Invalid command option.\n"
			usage
			exit 1
			;;
		--)
			shift
			break
			;;
		*)
			echo "$#"
			echo "internal error. panic!" 1>&2
			exit 1
			;;
		esac
	done
	echo "done getopts"
	args=("$@")
}

check_requirements() {
	# i expect these commands to be found
	for cmd in ip qemu-system-x86_64; do
		if ! command -v "$cmd" &>/dev/null; then
			echo "error: $cmd not found"
			exit 1
		fi
	done
}

get_vm_names() {
	if [[ "$all" == true ]]; then
		ls "$vm_dir" 2>/dev/null || true
	else
		echo "$hostnames" | tr ',' '\n'
	fi
}

tap_name_for_vm() {
	echo "tap_${1}"
}

pidfile_for_vm() {
	echo "$vm_dir/$1/$1.pid"
}

run_qemu_vm() {
	local name="$1"
	local tap_dev
	tap_dev=$(tap_name_for_vm "$name")
	local vm_dir="$vm_dir/$name"
	local pidfile
	pidfile=$(pidfile_for_vm "$name")

	mkdir -p "$vm_dir"

	# create tap device
	if ! ip link show "$tap_dev" &>/dev/null; then
		echo "creating tap $tap_dev"
		sudo ip tuntap add dev "$tap_dev" mode tap user "$user"
		sudo ip link set "$tap_dev" master "$bridge_if"
		sudo ip link set "$tap_dev" up
	fi

	echo "launching compute node $name"

	qemu-system-x86_64 \
		-name "$name" \
		-m "$memory" -smp "$cpu" \
		-enable-kvm \
		-netdev tap,id=net0,ifname="$tap_dev",script=no,downscript=no \
		-device rtl8139,netdev=net0 \
		-boot n \
		-nographic \
		-pidfile "$pidfile" \
		-daemonize
}

stop_vm() {
	local name="$1"
	local pidfile
	pidfile=$(pidfile_for_vm "$name")

	if [[ -f "$pidfile" ]]; then
		kill "$(cat "$pidfile")" && rm -f "$pidfile"
		echo "stopped $name"
	else
		echo "no running vm found for $name"
	fi
}

clean {
	if ! ip link show "$tap_dev" &>/dev/null; then
		echo "creating tap $tap_dev"
		sudo ip tuntap add dev "$tap_dev" mode tap user "$user"
		sudo ip link set "$tap_dev" master "$bridge_if"
		sudo ip link set "$tap_dev" up
	fi

	echo "launching compute node $name"

	qemu-system-x86_64 \
		-name "$name" \
		-m "$memory" -smp "$cpu" \
		-enable-kvm \
		-netdev tap,id=net0,ifname="$tap_dev",script=no,downscript=no \
		-device rtl8139,netdev=net0 \
		-boot n \
		-nographic \
		-pidfile "$pidfile" \
		-daemonize
}

### main

check_requirements

hostnames=""
image_path="$default_image"

get_opts "$@"

# access remaining positional arguments after options
echo "remaining arguments: $*"

case "${args[0]}" in
start)
	echo "start"
	# 	for node in $(get_vm_names); do
	# 		run_qemu_vm "$node"
	# 	done
	;;
stop)
	echo "stop"
	# 	for node in $(get_vm_names); do
	# 		stop_vm "$node"
	# 	done
	;;
restart)
	echo "restart"
	# 	for node in $(get_vm_names); do
	# 		stop_vm "$node"
	# 		sleep 1
	# 		run_qemu_vm "$node"
	# 	done
	;;
*)
	usage
	;;
esac
