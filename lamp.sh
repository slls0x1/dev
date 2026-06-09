#!/bin/bash
set -euo pipefail

MOUNTED=0 PKG_INSTALLED=0 FILES_COPIED=0 DB_SETUP=0 HTTPD_ENABLED=0

log()   { echo "[ OK ] $1"; }
err()   { echo "[ ERROR ] $1"; rollback; exit 1; }

rollback() {
  [[ $HTTPD_ENABLED -eq 1 ]] && systemctl disable --now httpd2.service 2>/dev/null || true
  [[ $DB_SETUP -eq 1 ]] && mariadb -u root -e "DROP DATABASE IF EXISTS webdb; DROP USER IF EXISTS 'webc'@'localhost';" 2>/dev/null || true
  [[ $FILES_COPIED -eq 1 ]] && rm -f /var/www/html/{index.php,logo.png} 2>/dev/null || true
  [[ $PKG_INSTALLED -eq 1 ]] && apt-get remove -y lamp-server >/dev/null 2>&1 || true
  [[ $MOUNTED -eq 1 ]] && umount /mnt/ 2>/dev/null || true
}

[[ $EUID -ne 0 ]] && err "Root privileges required"
log "Start"

apt-get update -qq >/dev/null 2>&1 || err "Failed to update package lists"
apt-get install -y lamp-server >/dev/null 2>&1 || err "Failed to install lamp-server package"
PKG_INSTALLED=1

mount /dev/sr0 /mnt/ >/dev/null 2>&1 && MOUNTED=1 || err "Failed to mount /dev/sr0 to /mnt"
cp /mnt/web/{index.php,logo.png} /var/www/html/ >/dev/null 2>&1 || err "Failed to copy web files"
FILES_COPIED=1

sed -i 's/\$username = "user"/\$username = "webc"/' /var/www/html/index.php >/dev/null 2>&1 || err "Failed to patch username"
sed -i 's/\$password = "password"/\$password = "Pessw0rd"/' /var/www/html/index.php >/dev/null 2>&1 || err "Failed to patch password"
sed -i 's/\$dbname = "db"/\$dbname = "webdb"/' /var/www/html/index.php >/dev/null 2>&1 || err "Failed to patch dbname"

systemctl enable --now mariadb.service >/dev/null 2>&1 || err "Failed to start MariaDB"

for i in {1..20}; do
  mariadb -u root -e "SELECT 1" >/dev/null 2>&1 && break
  sleep 1
done
[[ $i -ge 20 ]] && err "MariaDB not ready after 20s"

mariadb -u root <<'SQL' >/dev/null 2>&1 || err "Failed to configure database"
CREATE DATABASE IF NOT EXISTS webdb;
CREATE USER IF NOT EXISTS 'webc'@'localhost' IDENTIFIED BY 'Pessw0rd';
GRANT ALL PRIVILEGES ON webdb.* TO 'webc'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
DB_SETUP=1

mariadb -u webc -p'Pessw0rd' -D webdb < /mnt/web/dump.sql >/dev/null 2>&1 || err "Failed to import database dump"
systemctl enable --now httpd2.service >/dev/null 2>&1 || err "Failed to start HTTP service"
HTTPD_ENABLED=1

umount /mnt/ 2>/dev/null || true
log "Done"
