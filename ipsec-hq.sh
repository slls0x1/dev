#!/bin/bash
apt-get update -y
apt-get install strongswan -y
mkdir -p /etc/strongswan/swanctl
cat > /etc/strongswan/swanctl/swanctl.conf << 'EOF'
connections {
    gre-tunnel {
        local_addrs = 172.16.1.2
        remote_addrs = 172.16.2.2
        local {
            auth = psk
        }
        remote {
            auth = psk
        }
        children {
            gre-tunnel {
                start_action = start
                mode = transport
            }
        }
    }
}
secrets {
    ike-gre-tunnel {
        secret = "P@ssw0rd"
    }
}
EOF
iptables -I INPUT 1 -p udp --dport 500 -j ACCEPT
iptables -I INPUT 2 -p udp --dport 4500 -j ACCEPT
iptables -I INPUT 3 -p esp -j ACCEPT
iptables-save > /etc/sysconfig/iptables
systemctl enable --now strongswan
echo "Strongswan installed and configured for HQ node"
echo "Firewall rules applied and persisted"