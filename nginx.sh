#!/usr/bin/env bash
echo "[ OK ] Start"
[ "$(id -u)" -ne 0 ] && { echo "[ ERROR ] Root privileges required"; exit 1; }
command -v apt-get >/dev/null 2>&1 || { echo "[ ERROR ] apt-get package manager is missing"; exit 1; }
apt-get update -q >/dev/null 2>&1 || { echo "[ ERROR ] Failed to update package repositories"; exit 1; }
apt-get install -y nginx >/dev/null 2>&1 || { echo "[ ERROR ] Failed to install nginx package"; exit 1; }
command -v nginx >/dev/null 2>&1 || { echo "[ ERROR ] nginx executable not found in PATH"; exit 1; }
mkdir -p /etc/nginx/sites-available.d /etc/nginx/sites-enabled.d >/dev/null 2>&1 || { echo "[ ERROR ] Failed to create nginx configuration directories"; exit 1; }
cat <<EOF > /etc/nginx/sites-available.d/default.conf
server {
    listen 80;
    server_name web.au-team.irpo;
    location / {
        proxy_pass http://172.16.1.10:8080;
    }
}

server {
    listen 80;
    server_name docker.au-team.irpo;
    location / {
        proxy_pass http://172.16.2.10:8080;
    }
}
EOF
[ $? -ne 0 ] && { echo "[ ERROR ] Failed to write nginx configuration file"; exit 1; }
rm -f /etc/nginx/sites-enabled.d/default.conf 2>/dev/null
ln -sf /etc/nginx/sites-available.d/default.conf /etc/nginx/sites-enabled.d/ 2>/dev/null || { echo "[ ERROR ] Failed to create nginx configuration symlink"; exit 1; }
nginx -t >/dev/null 2>&1 || { echo "[ ERROR ] Nginx configuration test failed"; exit 1; }
systemctl enable --now nginx 2>/dev/null || { echo "[ ERROR ] Failed to enable and start nginx service"; exit 1; }
echo "[ OK ] Done"
