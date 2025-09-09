#!/usr/bin/env bash
set -e

# Create SD Network using RFC 1928 compliant subnet and also isn't the typical 172.17.0.0/16 Docker or WSL routes.
TAP_IF="tap0"
TAP_IP="172.22.0.1/24"
DHCP_RANGE_START="172.22.0.10"
DHCP_RANGE_END="172.22.0.100"
TAP_IF="tap0"
TFTP_ROOT="/srv/tftp"
DNSMASQ_CONF="/etc/dnsmasq.d/warewulf.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting Warewulf RPM-based Linux PXE provisioning setup..."

# 1. Check if RPM-based distro
if ! command -v rpm &>/dev/null; then
	echo "ERROR: rpm command not found. This script requires an RPM-based Linux distro."
	echo "Don't you dare install rpm on a non-traditional rpm distro to fool this script!"
	exit 1
fi

if [[ ! -f /etc/redhat-release ]]; then
	echo "ERROR: /etc/redhat-release not found. This script requires an RPM-based Linux distro."
	exit 1
fi

DISTRO_NAME=$(cat /etc/redhat-release)
echo "Detected RPM-based distro: $DISTRO_NAME"

# 2. Check if dnsmasq is installed, install if missing
if ! command -v dnsmasq &>/dev/null; then
	echo "dnsmasq not found. Installing..."
	if command -v dnf &>/dev/null; then
		sudo dnf install -y dnsmasq
	else
		sudo yum install -y dnsmasq
	fi
else
	echo "dnsmasq is already installed."
fi

# 3. Create tap interface owned by current user
echo "Creating tap interface $TAP_IF..."
if ip link show $TAP_IF &>/dev/null; then
	echo "$TAP_IF already exists, skipping creation."
else
	sudo ip tuntap add dev $TAP_IF mode tap user "$USER"
fi

# 4. Assign IP and bring tap interface up
echo "Configuring IP $TAP_IP on $TAP_IF..."
sudo ip addr flush dev $TAP_IF || true
sudo ip addr add $TAP_IP dev $TAP_IF
sudo ip link set dev $TAP_IF up

# 5. Create dnsmasq config for Warewulf PXE
echo "Writing dnsmasq config to $DNSMASQ_CONF..."
sudo tee $DNSMASQ_CONF >/dev/null <<EOF
interface=$TAP_IF
bind-interfaces
except-interface=lo
no-dhcp-interface=eth0,wlan0
listen-address=${TAP_IP%/*}

dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,12h

enable-tftp
tftp-root=$TFTP_ROOT

dhcp-boot=pxelinux.0

log-queries
log-dhcp
EOF

# 6. Restart dnsmasq service or run manually
if command -v systemctl &>/dev/null && systemctl is-active --quiet dnsmasq; then
	echo "Restarting dnsmasq service..."
	sudo systemctl restart dnsmasq
elif command -v systemctl &>/dev/null; then
	echo "Starting dnsmasq service..."
	sudo systemctl start dnsmasq
else
	echo "Systemd not detected. Please run dnsmasq manually with:"
	echo "sudo dnsmasq --no-daemon --conf-file=$DNSMASQ_CONF"
fi

echo "Setup complete. Use the separate script 'launch_qemu_vm.sh' to start VMs."
