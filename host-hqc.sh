#!/bin/bash
set -uo pipefail
BAK="/etc/hosts.bak.$$"
echo "[ OK ] Start"
rollback() {
  [[ -f "$BAK" ]] && cp -f "$BAK" /etc/hosts 2>/dev/null || true
  rm -f "$BAK" 2>/dev/null || true
}
fail() {
  echo "[ ERROR ] $1"
  rollback
  exit 1
}
[[ $EUID -ne 0 ]] && fail "Root privileges required"
cp -f /etc/hosts "$BAK" || fail "Failed to backup hosts file"
printf '%s\n%s\n' "172.16.1.1 web.au-team.irpo" "172.16.2.1 docker.au-team.irpo" >> /etc/hosts || fail "Failed to append entries to hosts file"
rm -f "$BAK" >/dev/null 2>&1 || true
echo "[ OK ] Done"
