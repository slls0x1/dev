#!/bin/bash
set -uo pipefail
[[ $EUID -ne 0 ]] && exit 1
echo "[ OK ] Start"
USERNAME="net_admin"
PASSWORD="P@ssw0rd"
SUDOERS="/etc/sudoers.d/${USERNAME}"
CREATED_USER=false
ADDED_WHEEL=false
CREATED_SUDOERS=false

rollback() {
    ${CREATED_SUDOERS} && rm -f "${SUDOERS}" 2>/dev/null || true
    ${ADDED_WHEEL} && gpasswd -d "${USERNAME}" wheel 2>/dev/null || true
    ${CREATED_USER} && userdel -r "${USERNAME}" 2>/dev/null || true
}

fail() {
    echo "[ ERROR ] $1"
    rollback
    exit 1
}

mkdir -p /etc/sudoers.d/ || fail "Failed to create sudoers directory"
id "${USERNAME}" &>/dev/null || { useradd "${USERNAME}" || fail "Failed to create user"; CREATED_USER=true; }
printf '%s:%s\n' "${USERNAME}" "${PASSWORD}" | chpasswd || fail "Failed to set password"
usermod -aG wheel "${USERNAME}" || fail "Failed to add user to wheel group"
ADDED_WHEEL=true
printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "${USERNAME}" > "${SUDOERS}" || fail "Failed to write sudoers file"
CREATED_SUDOERS=true
chmod 0440 "${SUDOERS}" || fail "Failed to set sudoers permissions"
echo "[ OK ] Done"
