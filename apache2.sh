#!/bin/bash
set -e
echo "[ OK ] Start"
apt-get update -y > /dev/null 2>&1
apt-get install -y apache2-htpasswd > /dev/null 2>&1
htpasswd -b -c /etc/nginx/.htpasswd WEB P@ssw0rd > /dev/null 2>&1
cat <<'EOF' > /etc/nginx/sites-available.d/default.conf
server {
    listen 80;
    server_name web.au-team.irpo;
    location / {
        proxy_pass http://172.16.1.10:8080;
        auth_basic "Restricted area";
        auth_basic_user_file /etc/nginx/.htpasswd;
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
systemctl restart nginx.service > /dev/null 2>&1
echo "[ OK ] Done"
