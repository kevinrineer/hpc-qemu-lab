#!/usr/bin/env bash
set -e 

destroy_bridge() {
	if ! ip link show "$BRIDGE_IF" &>/dev/null; then
		echo "Creating bridge $BRIDGE_IF ..."
		sudo ip link add name "$BRIDGE_IF" type bridge
		sudo ip addr add "$HOST_IP/24" dev "$BRIDGE_IF"
		sudo ip link set "$BRIDGE_IF" up
	else
		echo "Bridge $BRIDGE_IF already exists."
	fi
}

