#!/bin/bash
set -uo pipefail
echo "[ OK ] Start"
BAK_RESOLV="/etc/net/ifaces/enp7s1/resolv.conf.bak"
PKG_INSTALLED=0
RESOLV_BACKED_UP=0
ORIG_HOSTNAME=$(hostname)

rollback() {
  systemctl stop samba.service 2>/dev/null || true
  [[ $PKG_INSTALLED -eq 1 ]] && apt-get remove -y task-samba-dc >/dev/null 2>&1 || true
  rm -f /etc/samba/smb.conf 2>/dev/null || true
  rm -rf /var/lib/samba/ /var/cache/samba/ 2>/dev/null || true
  if [[ $RESOLV_BACKED_UP -eq 1 ]]; then
    mv -f "$BAK_RESOLV" /etc/net/ifaces/enp7s1/resolv.conf 2>/dev/null || true
  fi
  hostnamectl set-hostname "$ORIG_HOSTNAME" 2>/dev/null || true
  echo "127.0.0.1 localhost" > /etc/hosts 2>/dev/null || true
  rm -f "$BAK_RESOLV" 2>/dev/null || true
}

fail() {
  echo "[ ERROR ] $1"
  rollback
  exit 1
}

[[ $EUID -ne 0 ]] && fail "Root privileges required"
apt-get update -qq >/dev/null 2>&1 || fail "Failed to update package lists"
apt-get install -y task-samba-dc >/dev/null 2>&1 || fail "Failed to install task-samba-dc package"
PKG_INSTALLED=1
hostnamectl set-hostname br-srv.au-team.irpo >/dev/null 2>&1 || fail "Failed to set hostname"
cat > /etc/hosts <<'EOF'
127.0.0.1   localhost localhost.localdomain br-srv.br-srv.au-team.irpo br-srv
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
EOF
rm -f /etc/samba/smb.conf 2>/dev/null || true
rm -rf /var/lib/samba/ /var/cache/samba/ 2>/dev/null || true
mkdir -p /var/lib/samba/sysvol || fail "Failed to create samba sysvol directory"
[[ -f /etc/net/ifaces/enp7s1/resolv.conf ]] && { cp -f /etc/net/ifaces/enp7s1/resolv.conf "$BAK_RESOLV" || fail "Failed to backup resolv.conf"; RESOLV_BACKED_UP=1; }
printf "search au-team.irpo\nnameserver 127.0.0.1\n" > /etc/net/ifaces/enp7s1/resolv.conf || fail "Failed to write resolv.conf"
printf '%s\n' 'AU-TEAM.IRPO' 'AU-TEAM' 'dc' 'SAMBA_INTERNAL' '77.88.8.8' 'Pessw0rd' 'Pessw0rd' | samba-tool domain provision >/dev/null 2>&1 || fail "Failed to provision samba domain"
cp -f /var/lib/samba/private/krb5.conf /etc/krb5.conf || fail "Failed to copy krb5.conf"
systemctl enable --now samba.service >/dev/null 2>&1 || fail "Failed to start samba service"
systemctl restart network >/dev/null 2>&1 || fail "Failed to restart network service"
samba-tool group add hq >/dev/null 2>&1 || fail "Failed to create hq group"
for i in {1..5}; do
  samba-tool user add "hquser$i" 'Pessw0rd' >/dev/null 2>&1 || fail "Failed to create user hquser$i"
  samba-tool user setexpiry "hquser$i" --noexpiry >/dev/null 2>&1 || fail "Failed to set expiry for hquser$i"
  samba-tool group addmembers "hq" "hquser$i" >/dev/null 2>&1 || fail "Failed to add hquser$i to hq group"
done
rm -f "$BAK_RESOLV" 2>/dev/null || true
echo "[ OK ] Done"
