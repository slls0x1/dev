#!/bin/bash
set -uo pipefail
USERNAME="sshuser"
USER_UID=2026
USER_PASS="P@ssw0rd"
SUDOERS_FILE="/etc/sudoers.d/${USERNAME}"
USER_CREATED=0
SUDOERS_CREATED=0
echo "[ OK ] Start"
cleanup() {
  if [[ $USER_CREATED -eq 1 ]]; then
    userdel -r "${USERNAME}" 2>/dev/null || true
  fi
  if [[ $SUDOERS_CREATED -eq 1 ]]; then
    rm -f "${SUDOERS_FILE}" 2>/dev/null || true
  fi
}
fail() {
  echo "[ ERROR ] $1"
  cleanup
  exit 1
}
[[ $EUID -ne 0 ]] && fail "Root privileges required"
id "${USERNAME}" &>/dev/null && fail "User already exists"
useradd -u "${USER_UID}" "${USERNAME}" || fail "Failed to create user"
USER_CREATED=1
echo "${USERNAME}:${USER_PASS}" | chpasswd || fail "Failed to set password"
usermod -aG wheel "${USERNAME}" || fail "Failed to add user to wheel group"
printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "${USERNAME}" > "${SUDOERS_FILE}" || fail "Failed to write sudoers file"
SUDOERS_CREATED=1
chmod 0440 "${SUDOERS_FILE}" || fail "Failed to set file permissions"
echo "[ OK ] Done"
