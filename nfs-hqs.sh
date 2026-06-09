#!/bin/bash
set -uo pipefail
echo "[ OK ] Start"
EXP="/etc/exports"
DIR="/raid/nfs"
EXP_BAK="/etc/exports.bak"
PKG_INSTALLED=0
EXP_BACKED_UP=0
DIR_CREATED=0
EXP_WRITTEN=0
SVC_ENABLED=0
rollback() {
  if [[ $SVC_ENABLED -eq 1 ]]; then systemctl disable --now nfs-server.service 2>/dev/null || true; fi
  if [[ $EXP_WRITTEN -eq 1 ]]; then
    if [[ $EXP_BACKED_UP -eq 1 ]]; then cp -f "$EXP_BAK" "$EXP" 2>/dev/null || true; else rm -f "$EXP" 2>/dev/null || true; fi
  fi
  if [[ $DIR_CREATED -eq 1 ]]; then rm -rf "$DIR" 2>/dev/null || true; fi
  if [[ $PKG_INSTALLED -eq 1 ]]; then apt-get remove -y nfs-server >/dev/null 2>&1 || true; fi
  rm -f "$EXP_BAK" 2>/dev/null || true
}
fail() {
  echo "[ ERROR ] $1"
  rollback
  exit 1
}
[[ $EUID -ne 0 ]] && fail "Root privileges required"
apt-get update -qq >/dev/null 2>&1 || fail "Failed to update package lists"
apt-get install -y nfs-server >/dev/null 2>&1 || fail "Failed to install nfs-server package"
PKG_INSTALLED=1
[[ -f "$EXP" ]] && { cp -f "$EXP" "$EXP_BAK" || fail "Failed to backup exports"; EXP_BACKED_UP=1; }
mkdir -p "$DIR" || fail "Failed to create NFS directory"
DIR_CREATED=1
chmod -R 777 "$DIR" || fail "Failed to set directory permissions"
echo "/raid/nfs 192.168.2.0/28(rw,no_root_squash)" > "$EXP" || fail "Failed to write exports configuration"
EXP_WRITTEN=1
exportfs -arv >/dev/null 2>&1 || fail "Failed to apply exports"
systemctl enable --now nfs-server.service >/dev/null 2>&1 || fail "Failed to start NFS service"
SVC_ENABLED=1
rm -f "$EXP_BAK" >/dev/null 2>&1 || true
echo "[ OK ] Done"
