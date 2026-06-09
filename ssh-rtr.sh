#!/bin/bash
set -euo pipefail

echo "[ OK ] Start"

[[ $EUID -ne 0 ]] && { echo "[ ERROR ] Root privileges required"; exit 1; }

CONF="/etc/openssh/sshd_config"
BANNER="/etc/openssh/banner"
CONF_BAK="${CONF}.bak"
BANNER_BAK="${BANNER}.bak"

rollback() {
    [[ -f "$CONF_BAK" ]] && cp -f "$CONF_BAK" "$CONF"
    [[ -f "$BANNER_BAK" ]] && cp -f "$BANNER_BAK" "$BANNER" || rm -f "$BANNER"
    systemctl restart sshd.service >/dev/null 2>&1 || systemctl restart ssh.service >/dev/null 2>&1 || true
    echo "[ ERROR ] Rollback completed"
}

trap rollback ERR

cp -a "$CONF" "$CONF_BAK" 2>/dev/null || { echo "[ ERROR ] Config not found"; exit 1; }
[[ -f "$BANNER" ]] && cp -a "$BANNER" "$BANNER_BAK" || true

printf '%s\n' "Authorized access only" > "$BANNER" || { echo "[ ERROR ] Failed to write banner"; exit 1; }

grep -q "^Port 2026$" "$CONF" 2>/dev/null || printf '%s\n' "Port 2026" >> "$CONF"
grep -q "^AllowUsers net_admin$" "$CONF" 2>/dev/null || printf '%s\n' "AllowUsers net_admin" >> "$CONF"
grep -q "^MaxAuthTries 2$" "$CONF" 2>/dev/null || printf '%s\n' "MaxAuthTries 2" >> "$CONF"
grep -q "^Banner ${BANNER}$" "$CONF" 2>/dev/null || printf '%s\n' "Banner ${BANNER}" >> "$CONF"

if ! systemctl restart sshd.service >/dev/null 2>&1 && ! systemctl restart ssh.service >/dev/null 2>&1; then
    echo "[ ERROR ] Failed to restart SSH service"
    exit 1
fi

rm -f "$CONF_BAK" "$BANNER_BAK"
trap - ERR

echo "[ OK ] Done"
