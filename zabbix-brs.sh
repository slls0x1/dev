#!/bin/bash
set -e

HQ_SRV_IP="192.168.100.2"
HOSTNAME_BR="BR-SRV"

echo "=== Step 1/4: Adding hosts entry ==="
if ! grep -q "mon.au-team.irpo" /etc/hosts; then
    echo "192.168.100.2 mon.au-team.irpo" >> /etc/hosts
fi

echo "=== Step 2/4: Installing Zabbix Agent2 ==="
apt-get update
apt-get install -y zabbix-agent2

echo "=== Step 3/4: Configuring agent ==="
AGENT_CONF="/etc/zabbix/zabbix_agent2.conf"
if [ -f "$AGENT_CONF" ]; then
    sed -i "s/^Server=127.0.0.1/Server=${HQ_SRV_IP}/" "$AGENT_CONF"
    sed -i "s/^ServerActive=127.0.0.1/ServerActive=${HQ_SRV_IP}/" "$AGENT_CONF"
    sed -i "s/^Hostname=Zabbix server/Hostname=${HOSTNAME_BR}/" "$AGENT_CONF"
else
    echo "ERROR: $AGENT_CONF not found"
    exit 1
fi

echo "=== Step 4/4: Firewall and service ==="
iptables -A INPUT -p tcp --dport 10050 -s ${HQ_SRV_IP} -j ACCEPT
iptables -A INPUT -p tcp --dport 10051 -s ${HQ_SRV_IP} -j ACCEPT
iptables-save > /etc/sysconfig/iptables
systemctl enable --now zabbix_agent2

echo "BR-SRV agent is running."