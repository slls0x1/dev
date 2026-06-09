#!/bin/bash
set -uo pipefail
echo "[ OK ] Start"
MDADM_BAK="/etc/mdadm.conf.bak.$$"
FSTAB_BAK="/etc/fstab.bak.$$"
STAGE=0
rollback() {
  if [[ $STAGE -ge 6 ]]; then umount /dev/md0 2>/dev/null || true; fi
  if [[ $STAGE -ge 5 ]]; then rmdir /raid 2>/dev/null || true; fi
  if [[ $STAGE -ge 4 ]]; then cp -f "$FSTAB_BAK" /etc/fstab 2>/dev/null || true; rm -f "$FSTAB_BAK" 2>/dev/null || true; fi
  if [[ $STAGE -ge 3 ]]; then mdadm --stop /dev/md0 2>/dev/null || true; fi
  if [[ $STAGE -ge 2 ]]; then cp -f "$MDADM_BAK" /etc/mdadm.conf 2>/dev/null || true; rm -f "$MDADM_BAK" 2>/dev/null || true; fi
  rm -f "$MDADM_BAK" "$FSTAB_BAK" 2>/dev/null || true
}
fail() {
  echo "[ ERROR ] $1"
  rollback
  exit 1
}
[[ $EUID -ne 0 ]] && fail "Root privileges required"
[[ -e /dev/md0 ]] && fail "RAID device already exists"
mountpoint -q /raid 2>/dev/null && fail "Mount point already in use"
cp /etc/mdadm.conf "$MDADM_BAK" 2>/dev/null || true
STAGE=1
mdadm --create /dev/md0 -l 0 -n 2 /dev/sdb /dev/sdc --run --force >/dev/null 2>&1 || fail "Failed to create RAID0 array"
STAGE=2
mdadm --detail --scan --verbose >> /etc/mdadm.conf 2>/dev/null || fail "Failed to update mdadm configuration"
STAGE=3
mkfs.ext4 /dev/md0 >/dev/null 2>&1 || fail "Failed to format array with ext4"
STAGE=4
cp /etc/fstab "$FSTAB_BAK" || fail "Failed to backup fstab"
echo "/dev/md0 /raid ext4 defaults 0 0" >> /etc/fstab || fail "Failed to update fstab"
STAGE=5
mkdir -p /raid || fail "Failed to create mount point"
STAGE=6
mount /dev/md0 /raid >/dev/null 2>&1 || fail "Failed to mount array"
rm -f "$MDADM_BAK" "$FSTAB_BAK" 2>/dev/null || true
echo "[ OK ] Done"
