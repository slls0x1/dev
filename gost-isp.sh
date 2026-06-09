#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: this script must be run as root."
    exit 1
fi

echo "=== Nginx GOST SSL Configuration for ALT Linux ==="

echo "[1/5] Installing openssl-gost-engine..."
apt-get update
apt-get install -y openssl-gost-engine

echo "[2/5] Enabling GOST support..."
control openssl-gost enable 2>/dev/null || control openssl-gost enabled 2>/dev/null || true

echo "[3/5] Preparing SSL directory and copying certificates..."
mkdir -p /etc/nginx/ssl
cp web.au-team.irpo.* /etc/nginx/ssl/
cp docker.au-team.irpo.* /etc/nginx/ssl/

echo "[4/5] Applying Nginx configuration..."
cat > /etc/nginx/sites-available.d/default.conf << 'NGINX_CONF'
server {
    listen 443 ssl;
    server_name web.au-team.irpo;
    ssl_certificate /etc/nginx/ssl/web.au-team.irpo.cer;
    ssl_certificate_key /etc/nginx/ssl/web.au-team.irpo.key;
    ssl_ciphers GOST2012-GOST8912-GOST8912:HIGH:MEDIUM;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    location / {
        proxy_pass http://172.16.1.2:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        auth_basic "Restricted area";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}

server {
    listen 443 ssl;
    server_name docker.au-team.irpo;
    ssl_certificate /etc/nginx/ssl/docker.au-team.irpo.cer;
    ssl_certificate_key /etc/nginx/ssl/docker.au-team.irpo.key;
    ssl_ciphers GOST2012-GOST8912-GOST8912:HIGH:MEDIUM;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    location / {
        proxy_pass http://172.16.2.2:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX_CONF

echo "[5/5] Validating and restarting Nginx..."
nginx -t
systemctl restart nginx

echo "Done! Nginx is configured with GOST SSL."