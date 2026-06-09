#!/bin/bash
set -uo pipefail
IF_DIR="/etc/net/ifaces/gre1"
DIR_CREATED=0
echo "[ OK ] Start"
rollback() {
  if [[ $DIR_CREATED -eq 1 ]]; then
    rm -rf "${IF_DIR}" 2>/dev/null || true
  fi
  systemctl restart network 2>/dev/null || true
}
fail() {
  echo "[ ERROR ] $1"
  rollback
  exit 1
}
[[ $EUID -ne 0 ]] && fail "Root privileges required"
[[ -d "${IF_DIR}" ]] || DIR_CREATED=1
mkdir -p "${IF_DIR}" || fail "Failed to create interface directory"
cat > "${IF_DIR}/options" <<'EOF' || fail "Failed to write options file"
TYPE=iptun
TUNTYPE=gre
TUNLOCAL=172.16.1.2
TUNREMOTE=172.16.2.2
TUNOPTIONS='ttl 64'
HOST=enp7s1
EOF
echo "10.10.10.1/30" > "${IF_DIR}/ipv4address" || fail "Failed to set IPv4 address"
systemctl restart network || fail "Failed to restart network service"
echo "[ OK ] Done"
