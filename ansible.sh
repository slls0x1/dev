#!/bin/bash
set -euo pipefail
echo "[ OK ] Start"
D="/etc/ansible"
C="$D/ansible.cfg"
H="$D/hosts"
PKG_INSTALLED=0
CFG_CREATED=0
HOSTS_CREATED=0
rollback() {
  [[ $PKG_INSTALLED -eq 1 ]] && apt-get remove -y ansible sshpass >/dev/null 2>&1 || true
  [[ $HOSTS_CREATED -eq 1 ]] && rm -f "$H" 2>/dev/null || true
  [[ $CFG_CREATED -eq 1 ]] && rm -f "$C" 2>/dev/null || true
}
fail() {
  echo "[ ERROR ] $1"
  rollback
  exit 1
}
[[ $EUID -ne 0 ]] && fail "Root privileges required"
apt-get update >/dev/null 2>&1 || fail "Failed to update package lists"
apt-get install -y ansible sshpass >/dev/null 2>&1 || fail "Failed to install ansible and sshpass packages"
PKG_INSTALLED=1
mkdir -p "$D" >/dev/null 2>&1 || fail "Failed to create ansible directory"
cat > "$C" <<'EOF' || fail "Failed to write ansible configuration"
[defaults]
inventory = /etc/ansible/hosts
host_key_checking = False
EOF
CFG_CREATED=1
cat > "$H" <<'EOF' || fail "Failed to write ansible hosts inventory"
HQ-SRV ansible_host=192.168.1.10 ansible_user=sshuser ansible_password=P@ssw0rd ansible_port=2026
HQ-CLI ansible_host=192.168.2.10 ansible_user=sshuser ansible_password=P@ssw0rd ansible_port=2026
HQ-RTR ansible_host=192.168.5.1 ansible_user=net_admin ansible_password=P@ssw0rd ansible_port=2026
BR-RTR ansible_host=192.168.5.2 ansible_user=net_admin ansible_password=P@ssw0rd ansible_port=2026
[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
HOSTS_CREATED=1
chmod 600 "$H" || fail "Failed to set permissions on hosts file"
chmod 644 "$C" || fail "Failed to set permissions on configuration file"
echo "[ OK ] Done"
