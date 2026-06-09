#!/bin/bash
set -euo pipefail
echo "[ OK ] Start"
CONF="/etc/dnsmasq.conf"
BAK_CONF="/etc/dnsmasq.conf.bak"
PKG_INSTALLED=0
CONF_BACKED_UP=0

rollback() {
  systemctl stop dnsmasq.service 2>/dev/null || true
  if [[ $CONF_BACKED_UP -eq 1 ]]; then
    mv -f "$BAK_CONF" "$CONF" 2>/dev/null || true
  else
    rm -f "$CONF" 2>/dev/null || true
  fi
  if [[ $PKG_INSTALLED -eq 1 ]]; then
    apt-get remove -y dnsmasq >/dev/null 2>&1 || true
  fi
  rm -f "$BAK_CONF" 2>/dev/null || true
}

fail() {
  echo "[ ERROR ] $1"
  rollback
  exit 1
}

[[ $EUID -ne 0 ]] && fail "Root privileges required"
apt-get update >/dev/null 2>&1 || fail "Failed to update package lists"
apt-get install -y dnsmasq >/dev/null 2>&1 || fail "Failed to install dnsmasq package"
PKG_INSTALLED=1
if [[ -f "$CONF" ]]; then
  cp -f "$CONF" "$BAK_CONF" || fail "Failed to backup configuration"
  CONF_BACKED_UP=1
fi
cat > "$CONF" <<'EOF'
no-hosts
server=77.88.8.8
cache-size=1000
all-servers
no-negcache
interface=*
host-record=hq-rtr.au-team.irpo,192.168.100.1
host-record=hq-rtr.au-team.irpo,192.168.200.1
host-record=hq-rtr.au-team.irpo,192.168.99.1
host-record=hq-srv.au-team.irpo,192.168.100.2
host-record=hq-cli.au-team.irpo,192.168.200.2
address=/br-rtr.au-team.irpo/192.168.0.1
address=/br-srv.au-team.irpo/192.168.0.2
address=/docker.au-team.irpo/172.16.1.1
address=/web.au-team.irpo/172.16.2.1
EOF
systemctl enable --now dnsmasq.service >/dev/null 2>&1 || fail "Failed to start dnsmasq service"
rm -f "$BAK_CONF" >/dev/null 2>&1 || true
echo "[ OK ] Done"
