#!/bin/bash
set -euo pipefail
BASE_IF="enp7s2"
BASE_DIR="/etc/net/ifaces/${BASE_IF}"
BAK_DIR="/etc/net/ifaces/enp7s2.bak"
CREATED_VLANS=()
echo "[ OK ] Start"
cleanup() {
  local v
  for v in "${CREATED_VLANS[@]+"${CREATED_VLANS[@]}"}"; do
    rm -rf "/etc/net/ifaces/${v}" 2>/dev/null || true
  done
  if [[ -d "$BAK_DIR" ]]; then
    rm -rf "$BASE_DIR" 2>/dev/null || true
    mv "$BAK_DIR" "$BASE_DIR" 2>/dev/null || true
  fi
  systemctl restart network 2>/dev/null || true
}
fail() {
  echo "[ ERROR ] $1"
  cleanup
  exit 1
}
[[ $EUID -ne 0 ]] && fail "Root privileges required"
if [[ -d "$BASE_DIR" ]]; then
  rm -rf "$BAK_DIR" 2>/dev/null || true
  cp -a "$BASE_DIR" "$BAK_DIR" || fail "Failed to backup base interface directory"
fi
mkdir -p "$BASE_DIR" || fail "Failed to create base interface directory"
if [[ ! -f "${BASE_DIR}/options" ]] || ! grep -q "^TYPE=eth$" "${BASE_DIR}/options" 2>/dev/null; then
  echo "TYPE=eth" > "${BASE_DIR}/options" || fail "Failed to write base interface options"
fi
for config in "100:192.168.100.1/27" "200:192.168.200.1/24" "999:192.168.99.1/29"; do
  IFS=: read -r vid ip <<< "$config"
  DIR="/etc/net/ifaces/${BASE_IF}.${vid}"
  CREATED_VLANS+=("${BASE_IF}.${vid}")
  mkdir -p "$DIR" || fail "Failed to create VLAN directory for ${vid}"
  printf "VID=%s\nHOST=%s\nTYPE=vlan\n" "$vid" "$BASE_IF" > "$DIR/options" || fail "Failed to write VLAN options for ${vid}"
  echo "$ip" > "$DIR/ipv4address" || fail "Failed to set VLAN IP for ${vid}"
done
systemctl restart network || fail "Failed to restart network service"
rm -rf "$BAK_DIR" 2>/dev/null || true
echo "[ OK ] Done"
