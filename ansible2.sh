#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Starting Automated Inventory (Alt Linux) ===${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}[!] Script must be run as root (use sudo).${NC}"
  exit 1
fi

if ! command -v ansible &> /dev/null; then
    echo "[*] Ansible not found. Installing..."
    apt-get update -y -q
    apt-get install -y -q ansible
else
    echo "[*] Ansible already installed."
fi

ISO_PATH=""

if [ -n "$1" ]; then
    ISO_PATH="$1"
    echo "[*] Using ISO path from argument: $ISO_PATH"
elif [ -n "$ISO_LOCATION" ]; then
    ISO_PATH="$ISO_LOCATION"
    echo "[*] Using ISO path from environment variable: $ISO_PATH"
fi

if [ -z "$ISO_PATH" ] || [ ! -f "$ISO_PATH" ]; then
    echo "[*] Searching for Additional.iso..."
    SEARCH_PATHS=(
        "/root/Additional.iso"
        "./Additional.iso"
        "/home/user/Additional.iso"
        "/tmp/Additional.iso"
        "/var/lib/Additional.iso"
    )
    for path in "${SEARCH_PATHS[@]}"; do
        if [ -f "$path" ]; then
            ISO_PATH="$path"
            echo "[+] Found ISO at: $ISO_PATH"
            break
        fi
    done
fi

if [ -z "$ISO_PATH" ] || [ ! -f "$ISO_PATH" ]; then
    echo "[*] ISO not found as file. Checking CD-ROM devices..."
    CDROM_DEVICES=(
        "/dev/cdrom"
        "/dev/sr0"
        "/dev/dvd"
    )
    for dev in "${CDROM_DEVICES[@]}"; do
        if [ -b "$dev" ]; then
            echo "[+] Found CD-ROM device: $dev"
            MOUNT_POINT="/mnt/cdrom"
            mkdir -p "$MOUNT_POINT"
            if ! mountpoint -q "$MOUNT_POINT"; then
                mount "$dev" "$MOUNT_POINT" 2>/dev/null || true
            fi
            if [ -f "$MOUNT_POINT/playbook/inventory.yml" ]; then
                echo "[+] Playbook found on CD-ROM."
                MOUNT_POINT="/mnt/iso_additional"
                mkdir -p "$MOUNT_POINT"
                if ! mountpoint -q "$MOUNT_POINT"; then
                    mount "$dev" "$MOUNT_POINT" 2>/dev/null || true
                fi
                ISO_PATH="cdrom"
                break
            fi
        fi
    done
fi

if [ -z "$ISO_PATH" ]; then
    echo "[*] Checking already mounted filesystems..."
    MOUNTED_ISO=$(findmnt -t iso9660 -o TARGET -n 2>/dev/null | head -1)
    if [ -n "$MOUNTED_ISO" ]; then
        echo "[+] Found mounted ISO at: $MOUNTED_ISO"
        MOUNT_POINT="$MOUNTED_ISO"
        ISO_PATH="mounted"
    fi
fi

if [ "$ISO_PATH" = "cdrom" ] || [ "$ISO_PATH" = "mounted" ]; then
    echo "[*] Using mounted media at: $MOUNT_POINT"
elif [ -n "$ISO_PATH" ] && [ -f "$ISO_PATH" ]; then
    MOUNT_POINT="/mnt/iso_additional"
    mkdir -p "$MOUNT_POINT"
    if ! mountpoint -q "$MOUNT_POINT"; then
        echo "[*] Mounting $ISO_PATH to $MOUNT_POINT..."
        mount -o loop "$ISO_PATH" "$MOUNT_POINT"
    else
        echo "[*] ISO already mounted at $MOUNT_POINT."
    fi
else
    echo -e "${YELLOW}[!] Additional.iso not found anywhere.${NC}"
    echo "[*] You can specify path as argument: $0 /path/to/Additional.iso"
    echo "[*] Or set environment variable: ISO_LOCATION=/path/to/Additional.iso $0"
    echo "[*] Generating playbook without ISO..."
    MOUNT_POINT=""
fi

echo "[*] Creating report directory..."
mkdir -p /etc/ansible/PC-INFO

PLAYBOOK_DST="/etc/ansible/inventory_hq.yml"

PLAYBOOK_FOUND=false
if [ -n "$MOUNT_POINT" ] && [ -f "$MOUNT_POINT/playbook/inventory.yml" ]; then
    echo "[*] Copying playbook from media..."
    cp "$MOUNT_POINT/playbook/inventory.yml" "$PLAYBOOK_DST"
    PLAYBOOK_FOUND=true
fi

if [ "$PLAYBOOK_FOUND" = false ]; then
    echo "[*] Playbook not found. Generating automatically..."
    cat <<'EOF' > "$PLAYBOOK_DST"
---
- name: Automated inventory of workstations
  hosts: hq_workstations
  gather_facts: yes
  tasks:
    - name: Create report directory on control node
      file:
        path: /etc/ansible/PC-INFO
        state: directory
        mode: '0755'
      delegate_to: localhost
      run_once: true

    - name: Collect info and save to YAML file
      copy:
        content: |
          hostname: {{ ansible_hostname }}
          ip_address: {{ ansible_default_ipv4.address | default('Not defined') }}
          os_info: {{ ansible_distribution }} {{ ansible_distribution_version }}
        dest: "/etc/ansible/PC-INFO/{{ ansible_hostname }}.yml"
        mode: '0644'
      delegate_to: localhost
EOF
fi

INVENTORY_FILE="/etc/ansible/hosts"

if ! grep -q "\[hq_workstations\]" "$INVENTORY_FILE"; then
    echo "[*] Adding hq_workstations group to inventory..."
    cat <<EOF >> "$INVENTORY_FILE"

[hq_workstations]
HQ-SRV
HQ-CLI
EOF
fi

echo "[*] Running Ansible playbook..."
ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_DST"

echo -e "\n${GREEN}=== Inventory Results ===${NC}"
echo "Report files in /etc/ansible/PC-INFO/:"
ls -l /etc/ansible/PC-INFO/

echo -e "\n${GREEN}=== Report Contents ===${NC}"
for f in /etc/ansible/PC-INFO/*.yml; do
    if [ -f "$f" ]; then
        echo "--- $(basename "$f") ---"
        cat "$f"
        echo ""
    fi
done

if [ -n "$MOUNT_POINT" ] && [ "$ISO_PATH" != "mounted" ]; then
    echo "[*] Unmounting media..."
    umount "$MOUNT_POINT" 2>/dev/null || true
    rmdir "$MOUNT_POINT" 2>/dev/null || true
fi

echo -e "${GREEN}=== Automated Inventory Completed Successfully ===${NC}"