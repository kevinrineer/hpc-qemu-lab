#!/usr/bin/env bash
set -e

# === CONFIG
VM_NAME="head"
DISK_DIR="$HOME/vms"
IMAGE_DIR="$DISK_DIR/images"
DISK_PATH="$DISK_DIR/${VM_NAME}.qcow2"
SEED_ISO="$DISK_DIR/${VM_NAME}-seed.iso"
TAP_IF="tap0"
BRIDGE_IF="br0"
HOST_IP="172.22.0.1"
ARCH=$(uname -m)
MEMORY="2048"
CPU="2"

# === REQUIREMENTS
#


# === NETWORK
create_bridge() {
	if ! ip link show "$BRIDGE_IF" &>/dev/null; then
		echo "Creating bridge $BRIDGE_IF ..."
		sudo ip link add name "$BRIDGE_IF" type bridge
		sudo ip addr add "$HOST_IP/24" dev "$BRIDGE_IF"
		sudo ip link set "$BRIDGE_IF" up
	else
		echo "Bridge $BRIDGE_IF already exists."
	fi
}

create_tap() {
	if ! ip link show "$TAP_IF" &>/dev/null; then
		echo "Creating TAP device $TAP_IF ..."
		sudo ip tuntap add dev "$TAP_IF" mode tap user "$USER"
		sudo ip link set "$TAP_IF" master "$BRIDGE_IF"
		sudo ip link set "$TAP_IF" up
	else
		echo "TAP device $TAP_IF already exists."
	fi
}

# === DISK
create_disk_if_needed() {
	if [[ ! -f "$DISK_PATH" ]]; then
		echo "Creating data disk for VM at $DISK_PATH ..."
		mkdir -p "$(dirname "$DISK_PATH")"
		qemu-img create -f qcow2 "$DISK_PATH" 20G
	else
		echo "Disk image $DISK_PATH already exists."
	fi
}

# === CLOUD INIT
create_cloud_init_iso() {
	echo "Creating Cloud-Init seed ISO at $SEED_ISO ..."
	mkdir -p tmp-seed

	cat >tmp-seed/user-data <<EOF
#cloud-config
hostname: $VM_NAME
users:
  - name: learning-admin
    groups: wheel
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat ~/.ssh/id_rsa.pub)
package_update: true
packages:
  - epel-release
  - dnsmasq
  - git
  - golang
  - gpgme-devel
  - httpd
  - iproute
  - ipxe-bootimgs-aarch64
  - ipxe-bootimgs-x66
  - libassuan-devel
  - net-tools
  - nfs-utils
  - syslinux
  - tftp-server

runcmd:
  - mkdir -p /srv/tftp/pxelinux.cfg
  - cp /usr/share/syslinux/pxelinux.0 /srv/tftp/
  - cp /usr/share/syslinux/menu.c32 /srv/tftp/
  - cp /usr/share/syslinux/memdisk /srv/tftp/
  - cp /usr/share/syslinux/mboot.c32 /srv/tftp/
  - cp /usr/share/syslinux/chain.c32 /srv/tftp/
  - echo 'DEFAULT linux' > /srv/tftp/pxelinux.cfg/default
  - echo 'LABEL linux' >> /srv/tftp/pxelinux.cfg/default
  - echo '  KERNEL vmlinuz' >> /srv/tftp/pxelinux.cfg/default
  - echo '  APPEND initrd=initrd.img root=/dev/ram0' >> /srv/tftp/pxelinux.cfg/default
  - echo '  TIMEOUT 50' >> /srv/tftp/pxelinux.cfg/default
  - echo '  PROMPT 1' >> /srv/tftp/pxelinux.cfg/default
  - echo 'interface=eth0' > /etc/dnsmasq.d/pxe.conf
  - echo 'bind-interfaces' >> /etc/dnsmasq.d/pxe.conf
  - echo 'domain-needed' >> /etc/dnsmasq.d/pxe.conf
  - echo 'bogus-priv' >> /etc/dnsmasq.d/pxe.conf
  - echo 'dhcp-range=172.22.0.100,172.22.0.200,12h' >> /etc/dnsmasq.d/pxe.conf
  - echo 'dhcp-boot=pxelinux.0' >> /etc/dnsmasq.d/pxe.conf
  - echo 'enable-tftp' >> /etc/dnsmasq.d/pxe.conf
  - echo 'tftp-root=/srv/tftp' >> /etc/dnsmasq.d/pxe.conf
  - echo 'log-dhcp' >> /etc/dnsmasq.d/pxe.conf
  - systemctl enable --now dnsmasq
  - systemctl enable --now httpd
  - mkdir -p /opt/warewulf-src
  - git clone https://github.com/warewulf/warewulf.git /opt/warewulf-src
  - cd /opt/warewulf-src
  - |
  env \
    PREFIX=/opt/warewulf \
    SYSCONFDIR=/etc \
    IPXESOURCE=/usr/share/ipxe \
    WWPROVISIONDIR=/opt/warewulf/provision \
    WWOVERLAYDIR=/opt/warewulf/overlays \
    WWCHROOTDIR=/opt/warewulf/chroots \
    make all
  make install
  - systemctl enable --now warewulfd || true

EOF

	cat >tmp-seed/meta-data <<EOF
instance-id: ${VM_NAME}-001
local-hostname: $VM_NAME
EOF

	genisoimage -output "$SEED_ISO" -volid cidata -joliet -rock tmp-seed/user-data tmp-seed/meta-data >/dev/null 2>&1
	rm -rf tmp-seed
}

# === LAUNCH VM
launch_vm() {
	echo "Launching head node VM..."
	qemu-system-x86_64 \
		-name "$VM_NAME" \
		-m "$MEMORY" -smp "$CPU" \
		-enable-kvm \
		-netdev tap,id=net0,ifname="$TAP_IF",script=no,downscript=no \
		-device e1000,netdev=net0 \
		-drive file="$ISO_PATH",format=qcow2,if=virtio \
		-drive file="$SEED_ISO",format=raw,if=virtio \
		-drive file="$DISK_PATH",format=qcow2,if=virtio \
		-nographic
}

# === MAIN
main() {
	check_requirements
	create_bridge
	create_tap
	fetch_latest_image
	create_disk_if_needed
	create_cloud_init_iso
	launch_vm
}

main "$@"
