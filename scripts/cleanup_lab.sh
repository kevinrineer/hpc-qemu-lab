#!/usr/bin/env bash
set -euo pipefail

echo "Stopping lab..."
pkill -f qemu-system || true

echo "Removing disk images..."
rm -f ../images/*.qcow2

echo "Lab cleanup complete."

