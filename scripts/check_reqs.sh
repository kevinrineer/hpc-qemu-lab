#!/usr/bin/env bash

check_requirements() {
	local missing=()
	local os=""
	local pkgmgr=""
	local install_cmd=""
	declare -A packages

	# Detect OS and set package manager and package list
	if [[ "$OSTYPE" == "linux-gnu"* ]]; then
		if [ -f /etc/os-release ]; then
			# shellcheck disable=SC1091
			. /etc/os-release
			case "$ID" in
			ubuntu | debian)
				os="Ubuntu/Debian"
				pkgmgr="apt"
				install_cmd="sudo apt update && sudo apt install -y"
				packages=(
					[ip]="iproute2"
					[qemu - system - x86_64]="qemu-system-x86"
					[qemu - img]="qemu-utils"
					[curl]="curl"
					[jq]="jq"
					[genisoimage]="genisoimage"
				)
				;;
			rocky | rhel | centos)
				os="Rocky Linux / RHEL / CentOS"
				pkgmgr="dnf"
				install_cmd="sudo dnf install -y"
				packages=(
					[ip]="iproute"
					[qemu - system - x86_64]="qemu-kvm"
					[qemu - img]="qemu-img"
					[curl]="curl"
					[jq]="jq"
					[genisoimage]="genisoimage"
				)
				;;
			esac
		fi
	elif [[ "$OSTYPE" == "darwin"* ]]; then
		os="macOS"
		pkgmgr="brew"
		install_cmd="brew install"
		packages=(
			[ip]="iproute2mac" # optional or skipped
			[qemu - system - x86_64]="qemu"
			[qemu - img]="qemu"
			[curl]="curl"
			[jq]="jq"
			[genisoimage]="cdrtools"
		)
	fi

	# Check each command
	for cmd in "${!packages[@]}"; do
		if ! command -v "$cmd" &>/dev/null; then
			missing+=("$cmd")
		fi
	done

	# If missing, print message and exit
	if [ ${#missing[@]} -ne 0 ]; then
		echo "Error: The following required commands are missing:"
		for cmd in "${missing[@]}"; do
			echo "  - $cmd"
		done
		echo

		if [[ -n "$pkgmgr" ]]; then
			echo "To install them on $os, run:"
			echo -n "  $install_cmd"
			for cmd in "${missing[@]}"; do
				echo -n " ${packages[$cmd]}"
			done
			echo
		else
			echo "Could not detect OS or package manager. Please install the above commands manually."
		fi

		exit 1
	fi
}

check_requirements
