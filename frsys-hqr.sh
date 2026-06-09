#!/bin/bash
set -euo pipefail
SYSLOG_SERVER="192.168.100.2"
[ "$EUID" -ne 0 ] && { echo "Error: root privileges required"; exit 1; }

echo "Appending iptables rules for syslog traffic on HQ-RTR..."
iptables -A OUTPUT -d ${SYSLOG_SERVER} -p tcp --dport 514 -j ACCEPT
iptables -A INPUT -s ${SYSLOG_SERVER} -p tcp --sport 514 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo "Saving current iptables rules..."
iptables-save > /etc/sysconfig/iptables
echo "Rules appended and saved successfully."