#!/usr/bin/env bash
echo "[ OK ] Start"
[ "$(id -u)" -ne 0 ] && { echo "[ ERROR ] Root privileges required"; exit 1; }
command -v apt-get >/dev/null 2>&1 || { echo "[ ERROR ] apt-get package manager is missing"; exit 1; }
apt-get update -q >/dev/null 2>&1 || { echo "[ ERROR ] Failed to update package repositories"; exit 1; }
apt-get install -y chrony >/dev/null 2>&1 || { echo "[ ERROR ] Failed to install chrony package"; exit 1; }
command -v chronyd >/dev/null 2>&1 || { echo "[ ERROR ] chronyd executable not found in PATH"; exit 1; }
[ -f /etc/chrony.conf ] || { echo "[ ERROR ] chrony configuration file not found"; exit 1; }
cp -f /etc/chrony.conf /etc/chrony.conf.bak 2>/dev/null || { echo "[ ERROR ] Failed to backup chrony configuration"; exit 1; }
sed -i 's/^pool/#pool/' /etc/chrony.conf 2>/dev/null || { echo "[ ERROR ] Failed to comment out pool directives"; exit 1; }
cat <<EOF > /etc/chrony.conf
server ntp0.ntp-servers.net iburst prefer minstratum 4
local stratum 5
allow 0.0.0.0/0
EOF
[ $? -ne 0 ] && { echo "[ ERROR ] Failed to write chrony configuration"; exit 1; }
systemctl daemon-reload >/dev/null 2>&1 || { echo "[ ERROR ] Failed to reload systemd daemon"; exit 1; }
systemctl restart chronyd >/dev/null 2>&1 || { echo "[ ERROR ] Failed to restart chronyd service"; exit 1; }
sleep 3
systemctl is-active --quiet chronyd 2>/dev/null || { echo "[ ERROR ] chronyd service is not running after restart"; exit 1; }
chronyc tracking >/dev/null 2>&1 || { echo "[ ERROR ] chronyc tracking command failed - NTP sync not working"; exit 1; }
echo "[ OK ] Done"
