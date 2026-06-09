#!/bin/bash
set -euo pipefail
[ "$EUID" -ne 0 ] && { echo "Error: root privileges required"; exit 1; }

iptables -I INPUT 1 -p tcp --dport 514 -j ACCEPT

echo "Configuring syslog server and log rotation..."
apt-get install -y -qq rsyslog logrotate

if [ -f /etc/rsyslog.conf ]; then
    grep -q 'module(load="imuxsock")' /etc/rsyslog.conf || sed -i '1i module(load="imuxsock")' /etc/rsyslog.conf
    grep -q 'module(load="imklog")' /etc/rsyslog.conf || sed -i '1i module(load="imklog")' /etc/rsyslog.conf
fi

cat > /etc/rsyslog.d/50-server-receive.conf <<'EOF'
module(load="imtcp")
input(type="imtcp" port="514")
template(name="HostPerDir" type="string" string="/opt/%hostname%/%hostname%.log
")
*.warning action(
type="omfile"
dynaFile="HostPerDir"
createDirs="on"
dirCreateMode="0755"
fileCreateMode="0644"
)
EOF

cat > /etc/logrotate.d/hq-srv-logs <<'EOF'
/opt/*/*.log {
weekly
minsize 10M
compress
missingok
notifempty
create 0644 root root
sharedscripts
postrotate
/bin/systemctl reload rsyslog > /dev/null 2>&1 || true
endscript
}
EOF

rsyslogd -N1 && systemctl restart rsyslog
systemctl enable rsyslog logrotate &>/dev/null || true
echo "Server configuration and log rotation applied successfully."

mkdir -p /etc/sysconfig
iptables-save >> /etc/sysconfig/iptables