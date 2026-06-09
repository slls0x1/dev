#!/bin/bash
set -uo pipefail
echo "[ OK ] Start"
BAK_CONF="/etc/dhcp/dhcpd.conf.bak"
BAK_SYSCONF="/etc/sysconfig/dhcpd.bak"
IFACE="enp7s2.200"
PKG_INSTALLED=0
CONF_BACKED_UP=0
SYSCONF_BACKED_UP=0
ORIG_CONF_EXISTS=0

rollback() {
  systemctl stop dhcpd.service 2>/dev/null || true
  if [[ $CONF_BACKED_UP -eq 1 ]]; then
    mv -f "$BAK_CONF" /etc/dhcp/dhcpd.conf 2>/dev/null || true
  else
    rm -f /etc/dhcp/dhcpd.conf 2>/dev/null || true
  fi
  if [[ $SYSCONF_BACKED_UP -eq 1 ]]; then
    mv -f "$BAK_SYSCONF" /etc/sysconfig/dhcpd 2>/dev/null || true
  else
    rm -f /etc/sysconfig/dhcpd 2>/dev/null || true
  fi
  rm -f /var/lib/dhcp/dhcpd.leases 2>/dev/null || true
  [[ $PKG_INSTALLED -eq 1 ]] && apt-get remove -y dhcp-server >/dev/null 2>&1 || true
  rm -f "$BAK_CONF" "$BAK_SYSCONF" 2>/dev/null || true
}

fail() {
  echo "[ ERROR ] $1"
  rollback
  exit 1
}

[[ $EUID -ne 0 ]] && fail "Root privileges required"
apt-get update >/dev/null 2>&1 || fail "Failed to update package lists"
apt-get install -y dhcp-server >/dev/null 2>&1 || fail "Failed to install dhcp-server package"
PKG_INSTALLED=1
[[ -f /etc/dhcp/dhcpd.conf ]] && ORIG_CONF_EXISTS=1
[[ -f /etc/dhcp/dhcpd.conf ]] && { cp -f /etc/dhcp/dhcpd.conf "$BAK_CONF" || fail "Failed to backup configuration"; CONF_BACKED_UP=1; }
cat > /etc/dhcp/dhcpd.conf <<'EOF'
option domain-name "au-team.irpo";
option domain-name-servers 192.168.100.2;
default-lease-time 6000;
max-lease-time 72000;
authoritative;
subnet 192.168.200.0 netmask 255.255.255.0 {
range 192.168.200.2 192.168.200.254;
option routers 192.168.200.1;
}
EOF
mkdir -p /var/lib/dhcp || fail "Failed to create leases directory"
touch /var/lib/dhcp/dhcpd.leases || fail "Failed to create leases file"
chmod 644 /var/lib/dhcp/dhcpd.leases || fail "Failed to set leases permissions"
chown dhcpd:dhcpd /var/lib/dhcp/dhcpd.leases 2>/dev/null || true
[[ -f /etc/sysconfig/dhcpd ]] && { cp -f /etc/sysconfig/dhcpd "$BAK_SYSCONF" || fail "Failed to backup sysconfig"; SYSCONF_BACKED_UP=1; } || touch /etc/sysconfig/dhcpd
if grep -q '^DHCPDARGS=' /etc/sysconfig/dhcpd 2>/dev/null; then
  sed -i "s/^DHCPDARGS=.*/DHCPDARGS=\"${IFACE}\"/" /etc/sysconfig/dhcpd || fail "Failed to update sysconfig interface"
else
  echo "DHCPDARGS=\"${IFACE}\"" >> /etc/sysconfig/dhcpd || fail "Failed to set sysconfig interface"
fi
systemctl enable --now dhcpd.service >/dev/null 2>&1 || fail "Failed to start dhcpd service"
rm -f "$BAK_CONF" "$BAK_SYSCONF" 2>/dev/null || true
echo "[ OK ] Done"
