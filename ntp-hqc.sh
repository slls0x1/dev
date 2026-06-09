#!/usr/bin/env bash
echo "[ OK ] Start"
[ "$(id -u)" -ne 0 ] && { echo "[ ERROR ] Root privileges required"; exit 1; }
command -v apt-get >/dev/null 2>&1 || { echo "[ ERROR ] apt-get package manager is missing"; exit 1; }
apt-get update -y -q >/dev/null 2>&1 || { echo "[ ERROR ] Failed to update package repositories"; exit 1; }
apt-get install -y chronyd >/dev/null 2>&1 || { echo "[ ERROR ] Failed to install chronyd package"; exit 1; }
command -v chronyd >/dev/null 2>&1 || { echo "[ ERROR ] chronyd executable not found in PATH"; exit 1; }
echo "[ OK ] Done"
