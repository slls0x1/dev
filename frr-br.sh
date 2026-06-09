#!/bin/bash
set -euo pipefail
echo "[ OK ] Start"
PKG_INSTALLED=0
DAEMON_BACKED_UP=0
rollback() {
  systemctl stop frr.service 2>/dev/null || true
  systemctl disable frr.service 2>/dev/null || true
  [[ $PKG_INSTALLED -eq 1 ]] && apt-get remove -y frr >/dev/null 2>&1 || true
  if [[ $DAEMON_BACKED_UP -eq 1 ]]; then
    mv -f /etc/frr/daemons.bak /etc/frr/daemons 2>/dev/null || true
  fi
  rm -f /etc/frr/frr.conf 2>/dev/null || true
  rm -f /etc/frr/daemons.bak 2>/dev/null || true
}
fail() {
  echo "[ ERROR ] $1"
  rollback
  exit 1
}
[[ $EUID -ne 0 ]] && fail "Root privileges required"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1 || fail "Failed to update package lists"
apt-get install -y frr >/dev/null 2>&1 || fail "Failed to install frr package"
PKG_INSTALLED=1
[[ -f /etc/frr/daemons ]] && { cp -f /etc/frr/daemons /etc/frr/daemons.bak 2>/dev/null && DAEMON_BACKED_UP=1; }
sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons || fail "Failed to enable ospfd daemon"
systemctl enable --now frr.service >/dev/null 2>&1 || fail "Failed to start frr service"
vtysh >/dev/null 2>&1 <<'EOF' || fail "Failed to apply OSPF configuration"
configure terminal
router ospf
passive-interface default
network 10.10.10.0/30 area 0
network 192.168.0.0/28 area 0
exit
interface gre1
no ip ospf passive
ip ospf authentication message-digest
ip ospf message-digest-key 1 md5 P@ssw0rd
end
write memory
EOF
rm -f /etc/frr/daemons.bak 2>/dev/null || true
echo "[ OK ] Done"
