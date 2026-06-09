#!/bin/bash
set -uo pipefail
echo "[ OK ] Start"
COMPOSE_FILE="compose.yaml"
PKG_INSTALLED=0
MOUNTED=0
COMPOSE_CREATED=0
CONTAINERS_RUNNING=0
rollback() {
  if [[ $CONTAINERS_RUNNING -eq 1 ]]; then
    docker compose down -v --rmi all --remove-orphans >/dev/null 2>&1 || true
  fi
  if [[ $COMPOSE_CREATED -eq 1 ]]; then
    rm -f "$COMPOSE_FILE" 2>/dev/null || true
  fi
  if [[ $MOUNTED -eq 1 ]]; then
    umount /mnt/ 2>/dev/null || true
  fi
  if [[ $PKG_INSTALLED -eq 1 ]]; then
    apt-get remove -y docker-engine docker-compose-v2 >/dev/null 2>&1 || true
  fi
}
fail() {
  echo "[ ERROR ] $1"
  rollback
  exit 1
}
[[ $EUID -ne 0 ]] && fail "Root privileges required"
apt-get update -qq >/dev/null 2>&1 || fail "Failed to update package lists"
apt-get install -y docker-engine docker-compose-v2 >/dev/null 2>&1 || fail "Failed to install Docker packages"
PKG_INSTALLED=1
systemctl enable --now docker.service >/dev/null 2>&1 || fail "Failed to enable and start Docker service"
mount /dev/sr0 /mnt/ >/dev/null 2>&1 && MOUNTED=1 || true
docker load < /mnt/docker/site_latest.tar >/dev/null 2>&1 || fail "Failed to load site image"
docker load < /mnt/docker/mariadb_latest.tar >/dev/null 2>&1 || fail "Failed to load mariadb image"
cat > "$COMPOSE_FILE" <<'EOF' || fail "Failed to write compose file"
services:
  database:
    container_name: db
    image: mariadb:10.11
    restart: always
    ports:
      - "3306:3306"
    environment:
      MARIADB_DATABASE: "testdb"
      MARIADB_USER: "testc"
      MARIADB_PASSWORD: "Pessw0rd"
      MARIADB_ROOT_PASSWORD: "toor"
  app:
    container_name: testapp
    image: site:latest
    restart: always
    ports:
      - "8080:8000"
    environment:
      DB_TYPE: "maria"
      DB_HOST: "192.168.3.10"
      DB_PORT: "3306"
      DB_NAME: "testdb"
      DB_USER: "testc"
      DB_PASS: "Pessw0rd"
    depends_on:
      - database
EOF
COMPOSE_CREATED=1
docker compose up -d >/dev/null 2>&1 || fail "Failed to start Docker containers"
CONTAINERS_RUNNING=1
umount /mnt/ 2>/dev/null || true
echo "[ OK ] Done"
