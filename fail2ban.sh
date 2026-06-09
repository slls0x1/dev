#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "[!] Error: Please run this script as root or via sudo."
  exit 1
fi

echo "[*] Starting fail2ban configuration on HQ-SRV..."

echo "[*] Installing required packages..."
apt-get install -y fail2ban python3-module-systemd

echo "[*] Creating configuration file..."
cat << 'EOF' > /etc/fail2ban/jail.d/sshd-custom.local
[DEFAULT]
backend = systemd

[sshd]
enabled = true
port = 2026
filter = sshd
maxretry = 3
bantime = 60
findtime = 600
EOF

echo "[*] Creating runtime directory..."
mkdir -p /var/run/fail2ban

echo "[*] Stopping fail2ban..."
systemctl stop fail2ban 2>/dev/null
service fail2ban stop 2>/dev/null
sleep 2

echo "[*] Testing configuration..."
fail2ban-client -t

if [ $? -eq 0 ]; then
    echo "[*] Starting fail2ban..."
    service fail2ban start
    sleep 3
    
    echo "[*] Checking status..."
    fail2ban-client status sshd
    
    echo "[+] fail2ban configuration successfully completed!"
    echo "[i] sshuser account on port 2026 is now protected."
    echo "[i] To check banned IPs, use: fail2ban-client status sshd"
else
    echo "[!] Configuration test failed."
    fail2ban-client -t 2>&1
    exit 1
fi