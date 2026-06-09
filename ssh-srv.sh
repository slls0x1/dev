#!/bin/bash
set -uo pipefail
echo "[ OK ] Start"
CONF="/etc/openssh/sshd_config"
BANN="/etc/openssh/banner"
BAK_C="/etc/openssh/sshd_config.bak"
BAK_B="/etc/openssh/banner.bak"

rollback() {
  [[ -f "$BAK_C" ]] && cp -f "$BAK_C" "$CONF" 2>/dev/null || true
  if [[ -f "$BAK_B" ]]; then
    cp -f "$BAK_B" "$BANN" 2>/dev/null || true
  else
    rm -f "$BANN" 2>/dev/null || true
  fi
  systemctl restart sshd.service 2>/dev/null || true
  rm -f "$BAK_C" "$BAK_B" 2>/dev/null || true
}

fail() {
  echo "[ ERROR ] $1"
  rollback
  exit 1
}

[[ $EUID -ne 0 ]] && fail "Root privileges required"
cp -f "$CONF" "$BAK_C" || fail "Failed to backup configuration"
[[ -f "$BANN" ]] && cp -f "$BANN" "$BAK_B" || true
echo "Port 2026" >> "$CONF" || fail "Failed to append port"
echo "AllowUsers sshuser" >> "$CONF" || fail "Failed to append allowed user"
echo "MaxAuthTries 2" >> "$CONF" || fail "Failed to append max auth tries"
echo "Banner /etc/openssh/banner" >> "$CONF" || fail "Failed to append banner directive"
echo "Authorized access only" > "$BANN" || fail "Failed to write banner file"
/usr/sbin/sshd -t -f "$CONF" >/dev/null 2>&1 || fail "Invalid SSH configuration syntax"
systemctl restart sshd.service >/dev/null 2>&1 || fail "Failed to restart SSH service"
rm -f "$BAK_C" "$BAK_B" >/dev/null 2>&1 || fail "Failed to clean up backups"
echo "[ OK ] Done"
