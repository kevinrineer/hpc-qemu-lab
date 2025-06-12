#!/usr/bin/env bash
set -euox pipefail

# === Global Config ===
ROCKY_VERSION="${1:-10.0}"
QCOW_DIR="$(dirname "$0")/../images"
ARCH=$(uname -m)

normalize_architecture() {
  case "$ARCH" in
    x86_64) ARCH="x86_64" ;;
    aarch64) ARCH="aarch64" ;;
    *) echo "[ERROR] Unsupported architecture: $ARCH"; exit 1 ;;
  esac
}

# === URL Builders ===
get_base_url() {
  echo "https://download.rockylinux.org/pub/rocky/${ROCKY_VERSION}/images/${ARCH}"
}

get_latest_qcow_filename() {
  curl -s "${base_url}/" |
    # Strip the Major.Minor version to just the Major version (whole number)
    grep -oP "href=\"\K(Rocky-${ROCKY_VERSION%%.*}-GenericCloud-Base-.*${ARCH}\.qcow2)(?=\")"
}

# === Download & Verify ===
download_file_if_missing() {
  local url="${1}"
  local dest="${2}"
  if [[ ! -f "${dest}" ]]; then
    echo "Downloading $url"
    curl -L --progress-bar -o "${dest}" "${url}"
  else
    echo "[OK] ${dest} already exists"
  fi
}

verify_checksum() {
  local image_path="${1}"
  local checksum_path="${2}"

  local actual_hash expected_hash
  actual_hash=$(sha256sum "${image_path}" | awk '{print $1}')
  # Convert the checksum from "BSD" style sha256 to "GNU" style and save to the variable
  expected_hash=$(awk -F' = ' '/^SHA256/ {print $2}' "${checksum_path}")

  if [[ "${actual_hash}" == "${expected_hash}" ]]; then
    echo "[OK] Checksum verified."
  else
    echo "[ERROR] Checksum mismatch!"
    echo "Expected: ${expected_hash}"
    echo "Actual:   ${actual_hash}"
    exit 1
  fi
}

# === Main Operation ===
fetch_latest_image() {
  echo "Fetching latest Rocky qcow2 image..."
  mkdir -p "$QCOW_DIR"
  normalize_architecture

  base_url=$(get_base_url)
  qcow_filename=$(get_latest_qcow_filename)

  if [[ -z "${qcow_filename}" ]]; then
    echo "[ERROR] Could not find a suitable qcow2 image."
    exit 1
  fi

  qcow_url="${base_url}/${qcow_filename}"
  checksum_url="${qcow_url}.CHECKSUM"

  qcow_path="${QCOW_DIR}/${qcow_filename}"
  checksum_path="${qcow_path}.CHECKSUM"

  download_file_if_missing "${qcow_url}" "${qcow_path}"
  download_file_if_missing "${checksum_url}" "${checksum_path}"

  verify_checksum "${qcow_path}" "${checksum_path}"
}

# === Entry Point ===
fetch_latest_image
