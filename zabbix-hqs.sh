#!/bin/bash
set -e

HQ_SRV_IP="192.168.100.2"
HQ_SUB_1="192.168.100.0/27"
HQ_SUB_2="192.168.200.0/24"
BR_SUB="192.168.0.0/28"
DB_PASS="P@ssw0rd"
DB_NAME="zabbix"
DB_USER="zabbix"
ZABBIX_ADMIN_PASS="P@ssw0rd"

echo "=== Step 1/10: Adding hosts entry ==="
grep -q "mon.au-team.irpo" /etc/hosts || echo "192.168.100.2 mon.au-team.irpo hq-srv.au-team.irpo" >> /etc/hosts

echo "=== Step 2/10: Installing packages ==="
apt-get update
apt-get install -y mariadb-server apache2 zabbix-server-mysql zabbix-phpfrontend-apache2 zabbix-phpfrontend-php8.2 zabbix-agent2 zabbix-common-database-mysql php8.2-mysqlnd php8.2-bcmath php8.2-mbstring php8.2-gd php8.2-xml php8.2-ldap

echo "=== Step 3/10: Configuring MariaDB ==="
systemctl enable --now mariadb
sleep 3
mariadb -e "SET GLOBAL log_bin_trust_function_creators = 1;" 2>/dev/null || true
mariadb -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
mariadb -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" 2>/dev/null || true
mariadb -e "SET PASSWORD FOR '${DB_USER}'@'localhost' = PASSWORD('${DB_PASS}');" 2>/dev/null || true
mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"

echo "=== Step 4/10: Importing Zabbix schema ==="
FOUND_SQL=$(find / -type f \( -name "schema.sql" -o -name "schema.sql.gz" -o -name "server.sql" -o -name "server.sql.gz" \) 2>/dev/null | grep -i zabbix | head -1)
if [ -z "$FOUND_SQL" ]; then
    FOUND_SQL=$(find / -name "*.sql.gz" 2>/dev/null | grep -i zabbix | head -1)
fi
if [ -z "$FOUND_SQL" ]; then
    FOUND_SQL=$(find / -name "*.sql" 2>/dev/null | grep -i zabbix | head -1)
fi

if [ -z "$FOUND_SQL" ]; then
    echo "ERROR: Zabbix SQL files not found"
    exit 1
fi

SQL_DIR=$(dirname "$FOUND_SQL")
echo "Found: $FOUND_SQL"

TABLE_COUNT=$(mariadb -u${DB_USER} -p"${DB_PASS}" ${DB_NAME} -e "SHOW TABLES;" 2>/dev/null | wc -l)

if [ "$TABLE_COUNT" -lt 10 ]; then
    echo "Importing schema..."
    if [[ "$FOUND_SQL" == *.gz ]]; then
        zcat "$FOUND_SQL" | mariadb -u${DB_USER} -p"${DB_PASS}" ${DB_NAME}
    else
        mariadb -u${DB_USER} -p"${DB_PASS}" ${DB_NAME} < "$FOUND_SQL"
    fi
    for extra in images data; do
        [ -f "$SQL_DIR/${extra}.sql.gz" ] && zcat "$SQL_DIR/${extra}.sql.gz" | mariadb -u${DB_USER} -p"${DB_PASS}" ${DB_NAME}
        [ -f "$SQL_DIR/${extra}.sql" ] && mariadb -u${DB_USER} -p"${DB_PASS}" ${DB_NAME} < "$SQL_DIR/${extra}.sql"
    done
    echo "Schema imported."
else
    echo "Schema already imported ($TABLE_COUNT tables)."
fi

echo "=== Step 5/10: Configuring Zabbix Server ==="
ZABBIX_CONF="/etc/zabbix/zabbix_server.conf"
sed -i "s|^# DBPassword=.*|DBPassword=${DB_PASS}|" "$ZABBIX_CONF" 2>/dev/null || true
sed -i "s|^DBPassword=.*|DBPassword=${DB_PASS}|" "$ZABBIX_CONF"
grep -q "^DBPassword=" "$ZABBIX_CONF" || echo "DBPassword=${DB_PASS}" >> "$ZABBIX_CONF"

echo "=== Step 6/10: Starting Zabbix services ==="
systemctl daemon-reload
systemctl enable zabbix_mysql 2>/dev/null || true
systemctl start zabbix_mysql
systemctl enable zabbix_agent2
systemctl start zabbix_agent2
sleep 2
systemctl is-active zabbix_mysql && echo "zabbix_mysql: OK"
systemctl is-active zabbix_agent2 && echo "zabbix_agent2: OK"

echo "=== Step 7/10: Setting admin username and password ==="
PASS_HASH=$(php -r "echo password_hash('${ZABBIX_ADMIN_PASS}', PASSWORD_BCRYPT);")

# Определяем правильное имя колонки (username для Zabbix 7.x, alias для 6.x)
COL_NAME=$(mariadb -u${DB_USER} -p"${DB_PASS}" ${DB_NAME} -e "SHOW COLUMNS FROM users;" 2>/dev/null | grep -E "^(username|alias)" | awk '{print $1}' | head -1)

if [ -n "$COL_NAME" ]; then
    # Обновляем пароль И меняем логин с Admin на admin
    mariadb -u${DB_USER} -p"${DB_PASS}" ${DB_NAME} -e "UPDATE users SET passwd='${PASS_HASH}', ${COL_NAME}='admin' WHERE ${COL_NAME}='Admin';"
    echo "Username changed to 'admin', password set to: ${ZABBIX_ADMIN_PASS}"
else
    echo "ERROR: Cannot find username/alias column in users table"
fi

echo "=== Step 8/10: Creating directories ==="
mkdir -p /var/www/webapps/zabbix/ui/conf
chmod 777 /var/www/webapps/zabbix/ui/conf
mkdir -p /etc/httpd2/conf/addon.d

echo "=== Step 9/10: Configuring Apache ==="
APACHE_CONF="/etc/httpd2/conf/httpd2.conf"
grep -q "IncludeOptional conf/addon.d/\*.conf" "$APACHE_CONF" || echo "IncludeOptional conf/addon.d/*.conf" >> "$APACHE_CONF"

rm -f /etc/httpd2/conf/addon.d/A.zabbix.conf
cat > /etc/httpd2/conf/addon.d/zabbix.conf <<EOF
Alias /zabbix /var/www/webapps/zabbix/ui

<Directory /var/www/webapps/zabbix/ui>
    Options FollowSymLinks
    AllowOverride None
    Require ip ${HQ_SUB_1} ${HQ_SUB_2}

    php_value max_execution_time 300
    php_value memory_limit 128M
    php_value post_max_size 16M
    php_value upload_max_filesize 2M
    php_value max_input_time 300
    php_value max_input_vars 10000
    php_value date.timezone Europe/Moscow
</Directory>

<VirtualHost *:80>
    ServerName mon.au-team.irpo
    DocumentRoot /var/www/webapps/zabbix/ui
</VirtualHost>
EOF

httpd2 -t
systemctl enable httpd2
systemctl restart httpd2
sleep 2
systemctl is-active httpd2 && echo "httpd2: OK"

echo "=== Step 10/10: Configuring firewall ==="
iptables -A INPUT -p tcp --dport 80 -s ${HQ_SUB_1} -j ACCEPT 2>/dev/null || true
iptables -A INPUT -p tcp --dport 80 -s ${HQ_SUB_2} -j ACCEPT 2>/dev/null || true
iptables -A INPUT -p tcp --dport 10051 -s ${BR_SUB} -j ACCEPT 2>/dev/null || true
iptables -A INPUT -p tcp --dport 10050 -s ${BR_SUB} -j ACCEPT 2>/dev/null || true
iptables-save > /etc/sysconfig/iptables

echo ""
echo "========================================================"
echo "DONE!"
echo "URL: http://mon.au-team.irpo/zabbix"
echo "Login: admin"
echo "Password: ${ZABBIX_ADMIN_PASS}"
echo "DB Password: ${DB_PASS}"
echo "========================================================"