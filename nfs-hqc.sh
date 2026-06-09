#!/bin/bash
set -uo pipefail
MOUNT_POINT="/mnt/nfs"
SERVER_IP="192.168.1.10"
SHARE="/raid/nfs"
FSTAB_ENTRY="${SERVER_IP}:${SHARE} ${MOUNT_POINT} nfs defaults,_netdev 0 0"
FSTAB_BAK="/etc/fstab.bak.$$"
STAGE=0
DIR_EXISTS=0
echo "[ OK ] Start"

rollback() {
  if mountpoint -q "${MOUNT_POINT}" 2>/dev/null; then
    umount "${MOUNT_POINT}" 2>/dev/null || true
  fi
  if [[ $STAGE -ge 4 ]]; then
    if [[ -f "$FSTAB_BAK" ]]; then
      cp -f "$FSTAB_BAK" /etc/fstab 2>/dev/null || true
    fi
  fi
  if [[ $STAGE -ge 2 && $DIR_EXISTS -eq 0 ]]; then
    rmdir "${MOUNT_POINT}" 2>/dev/null || true
  fi
  rm -f "$FSTAB_BAK" 2>/dev/null || true
}

fail() {
  echo "[ ERROR ] $1"
  rollback
  exit 1
}

[[ $EUID -ne 0 ]] && fail "Root privileges required"
mountpoint -q "${MOUNT_POINT}" 2>/dev/null && fail "Mount point already active"
grep -q "${SERVER_IP}:${SHARE}" /etc/fstab 2>/dev/null && fail "NFS entry already exists in fstab"

[[ -d "${MOUNT_POINT}" ]] && DIR_EXISTS=1

cp /etc/fstab "$FSTAB_BAK" || fail "Failed to backup fstab"
STAGE=1

mkdir -p "${MOUNT_POINT}" || fail "Failed to create mount directory"
STAGE=2

chmod -R 777 "${MOUNT_POINT}" || fail "Failed to set permissions"
STAGE=3

echo "${FSTAB_ENTRY}" >> /etc/fstab || fail "Failed to update fstab"
STAGE=4

mount "${MOUNT_POINT}" >/dev/null 2>&1 || fail "Failed to mount NFS share"

rm -f "$FSTAB_BAK" >/dev/null 2>&1 || true
echo "[ OK ] Done"
