#!/usr/bin/env bash
echo "[ OK ] Start"
[ "$(id -u)" -ne 0 ] && { echo "[ ERROR ] Root privileges required"; exit 1; }
command -v ip >/dev/null 2>&1 || { echo "[ ERROR ] iproute2 package is missing"; exit 1; }
ip link show enp7s1 >/dev/null 2>&1 || { echo "[ ERROR ] Network interface em0s3 is not active or does not exist"; exit 1; }
apt-get update -y -q >/dev/null 2>&1 || { echo "[ ERROR ] Failed to update package repositories"; exit 1; }
apt-get install -y iptables >/dev/null 2>&1 || { echo "[ ERROR ] Failed to install iptables"; exit 1; }
command -v iptables >/dev/null 2>&1 || { echo "[ ERROR ] iptables executable not found in PATH"; exit 1; }
iptables -t nat -A PREROUTING -i enp7s1 -p tcp --dport 2026 -j DNAT --to-destination 192.168.1.10:2026 2>/dev/null || { echo "[ ERROR ] Failed to apply DNAT rule for port 2026"; exit 1; }
iptables -t nat -A PREROUTING -i enp7s1 -p tcp --dport 8080 -j DNAT --to-destination 192.168.1.10:80 2>/dev/null || { echo "[ ERROR ] Failed to apply DNAT rule for port 8080"; exit 1; }
iptables-save > /etc/sysconfig/iptables 2>/dev/null || { echo "[ ERROR ] Failed to persist firewall rules"; exit 1; }
systemctl enable --now iptables 2>/dev/null || { echo "[ ERROR ] Failed to enable and start iptables service"; exit 1; }
echo "[ OK ] Done"
