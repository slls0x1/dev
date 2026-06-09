#!/usr/bin/env bash
echo "[ OK ] Start"
[ "$(id -u)" -ne 0 ] && { echo "[ ERROR ] Root privileges required"; exit 1; }
command -v apt-get >/dev/null 2>&1 || { echo "[ ERROR ] apt-get package manager is missing"; exit 1; }
apt-get update -y -q >/dev/null 2>&1 || { echo "[ ERROR ] Failed to update package repositories"; exit 1; }
apt-get install -y chronyd >/dev/null 2>&1 || { echo "[ ERROR ] Failed to install chronyd package"; exit 1; }
command -v chronyd >/dev/null 2>&1 || { echo "[ ERROR ] chronyd executable not found in PATH"; exit 1; }
[ -f /etc/chrony.conf ] || { echo "[ ERROR ] chrony configuration file not found"; exit 1; }
cp -f /etc/chrony.conf /etc/chrony.conf.bak 2>/dev/null || { echo "[ ERROR ] Failed to backup chrony configuration"; exit 1; }
sed -i 's/^pool/#pool/' /etc/chrony.conf 2>/dev/null || { echo "[ ERROR ] Failed to comment out pool directives"; exit 1; }
if ! grep -qxF 'server 172.16.2.1 iburst' /etc/chrony.conf; then
    echo 'server 172.16.2.1 iburst' >> /etc/chrony.conf 2>/dev/null || { echo "[ ERROR ] Failed to append NTP server configuration"; exit 1; }
fi
systemctl daemon-reload >/dev/null 2>&1 || { echo "[ ERROR ] Failed to reload systemd daemon"; exit 1; }
systemctl enable --now chronyd >/dev/null 2>&1 || { echo "[ ERROR ] Failed to enable and start chronyd service"; exit 1; }
sleep 3
systemctl is-active --quiet chronyd 2>/dev/null || { echo "[ ERROR ] chronyd service is not running"; exit 1; }
chronyc sources -v 2>/dev/null | grep -q '\*' || { echo "[ ERROR ] No synchronized NTP source found"; exit 1; }
echo "[ OK ] Done"
