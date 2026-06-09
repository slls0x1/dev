#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: this script must be run as root."
    exit 1
fi

echo "=== GOST OpenSSL Setup for ALT Linux ==="

echo "[1/5] Updating repositories and installing openssl-gost-engine..."
apt-get update
apt-get install -y openssl-gost-engine || {
    echo "Package openssl-gost-engine not found."
    exit 1
}

echo "[2/5] Enabling GOST support in OpenSSL..."
control openssl-gost enable 2>/dev/null || control openssl-gost enabled 2>/dev/null || \
    echo "Warning: automatic activation failed."

echo "[3/5] Generating CA key and self-signed certificate..."
openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:TCB -out ca.key
openssl req -new -x509 -md_gost12_256 -days 30 -key ca.key -out ca.cer -subj "/CN=hq-srv.au-team.irpo"

echo "[4/5] Generating service keys and CSRs..."
openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:A -out web.au-team.irpo.key
openssl req -new -md_gost12_256 -key web.au-team.irpo.key -out web.au-team.irpo.csr -subj "/CN=web.au-team.irpo"

openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:A -out docker.au-team.irpo.key
openssl req -new -md_gost12_256 -key docker.au-team.irpo.key -out docker.au-team.irpo.csr -subj "/CN=docker.au-team.irpo"

echo "[5/5] Signing certificates with CA..."
openssl x509 -req -in web.au-team.irpo.csr -CA ca.cer -CAkey ca.key -CAcreateserial -out web.au-team.irpo.cer -days 30
openssl x509 -req -in docker.au-team.irpo.csr -CA ca.cer -CAkey ca.key -CAcreateserial -out docker.au-team.irpo.cer -days 30

echo "Done! All files created in the current directory:"
ls -lh *.key *.csr *.cer *.srl