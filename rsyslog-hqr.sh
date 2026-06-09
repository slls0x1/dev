#!/bin/bash
set -euo pipefail
DEVICE_HOST="hq-rtr.au-team.irpo"
LOG_SERVER_IP="192.168.100.2"
LOG_SERVER_HOST="hq-srv.au-team.irpo"
CONF_FILE="/etc/rsyslog.d/50-client-forward.conf"
[ "$EUID" -ne 0 ] && { echo "Error: root privileges required"; exit 1; }

echo "Configuring rsyslog on ${DEVICE_HOST}..."
if ! command -v rsyslogd &> /dev/null; then
    echo "Installing rsyslog package..."
    apt-get update -qq && apt-get install -y -qq rsyslog
fi

if [ -f /etc/rsyslog.conf ]; then
    grep -q 'module(load="imuxsock")' /etc/rsyslog.conf || sed -i '1i module(load="imuxsock")' /etc/rsyslog.conf
    grep -q 'module(load="imklog")' /etc/rsyslog.conf || sed -i '1i module(load="imklog")' /etc/rsyslog.conf
fi

cat > "$CONF_FILE" <<EOF
if \$hostname != "${LOG_SERVER_HOST}" then {
*.warning @@${LOG_SERVER_IP}:514
}
EOF

if ! rsyslogd -N1 &>/dev/null; then
    echo "Error: rsyslog configuration syntax check failed."
    rm -f "$CONF_FILE"
    exit 1
fi

systemctl restart rsyslog
systemctl enable rsyslog &>/dev/null || true
echo "Configuration applied and service restarted."
echo "Test command: logger -p warning 'Test from ${DEVICE_HOST}'"

mkdir -p /etc/sysconfig
iptables-save >> /etc/sysconfig/iptables