#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: this script must be run as root."
    exit 1
fi

echo "=== CUPS & PDF Printer Setup ==="

echo "[1/3] Updating repositories and installing packages..."
apt-get update
apt-get install -y cups cups-pdf

echo "[2/3] Enabling and starting CUPS service..."
systemctl enable --now cups

echo "[3/3] Configuring CUPS for network sharing..."
cupsctl --share-printers --remote-any

echo "Done! CUPS is installed and configured for sharing."