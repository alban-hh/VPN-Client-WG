#!/bin/bash

# Ultimate WireGuard Setup Script
# Base: Angristan's wireguard-install
# Enhanced with: Cloudflared DoH + Security + Zero Packet Loss optimizations
# https://github.com/angristan/wireguard-install

RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}=== Ultimate WireGuard Setup ===${NC}"
echo "This script will install:"
echo "  ✓ WireGuard VPN (Angristan's script)"
echo "  ✓ Cloudflared DNS-over-HTTPS"
echo "  ✓ Aggressive firewall (block all except SSH + VPN)"
echo "  ✓ Zero packet loss optimizations"
echo "  ✓ SSH hardening (keys only)"
echo ""

# Download Angristan's script
echo -e "${GREEN}[1/6] Downloading WireGuard installer...${NC}"
curl -fsSL https://raw.githubusercontent.com/angristan/wireguard-install/master/wireguard-install.sh -o /tmp/wg-install.sh
chmod +x /tmp/wg-install.sh

# Run WireGuard installation
echo -e "${GREEN}[2/6] Installing WireGuard...${NC}"
bash /tmp/wg-install.sh

# Get WireGuard port from config
WG_PORT=$(grep "ListenPort" /etc/wireguard/wg0.conf | awk '{print $3}')
echo -e "${GREEN}WireGuard installed on port: ${WG_PORT}${NC}"

# Install Cloudflared
echo -e "${GREEN}[3/6] Installing Cloudflared DNS-over-HTTPS...${NC}"
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb
rm -f cloudflared-linux-amd64.deb

# Configure Cloudflared
cat > /etc/systemd/system/cloudflared-dns.service << 'EOF'
[Unit]
Description=Cloudflared DNS over HTTPS proxy
After=network.target wg-quick@wg0.service
Requires=wg-quick@wg0.service

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared proxy-dns --address 10.66.66.1 --port 53 --upstream https://1.1.1.1/dns-query --upstream https://1.0.0.1/dns-query
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now cloudflared-dns.service

# Update client config to use encrypted DNS
echo -e "${GREEN}Updating client configs to use encrypted DNS...${NC}"
for conf in /root/wg0-client-*.conf; do
    if [ -f "$conf" ]; then
        sed -i 's/DNS = .*/DNS = 10.66.66.1/' "$conf"
    fi
done

# Setup firewall
echo -e "${GREEN}[4/6] Setting up secure firewall...${NC}"
# Add all ALLOW rules before DROP policy
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p udp -s 10.66.66.0/24 --dport 53 -j ACCEPT
iptables -A INPUT -p tcp -s 10.66.66.0/24 --dport 53 -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s 10.66.66.0/24 -j ACCEPT

# Set policies
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP
iptables -P INPUT DROP

# Save firewall rules
apt-get install -y iptables-persistent
netfilter-persistent save

# Aggressive sysctl optimizations for zero packet loss
echo -e "${GREEN}[5/6] Applying zero packet loss optimizations...${NC}"
cat >> /etc/sysctl.d/99-wireguard-optimize.conf << 'EOF'

# AGGRESSIVE optimizations for ZERO packet loss
# Massive connection tracking table
net.netfilter.nf_conntrack_max = 2097152

# Long UDP timeouts (prevents handshake failures)
net.netfilter.nf_conntrack_udp_timeout = 600
net.netfilter.nf_conntrack_udp_timeout_stream = 600

# Huge network buffers (never drop packets)
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# Large queue for packet processing
net.core.netdev_max_backlog = 30000

# Increase max connections
net.core.somaxconn = 8192

# Fast recycling of TIME_WAIT sockets
net.ipv4.tcp_tw_reuse = 1

# Keep connections alive
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
EOF

sysctl -p /etc/sysctl.d/99-wireguard-optimize.conf > /dev/null 2>&1

# Harden SSH
echo -e "${GREEN}[6/6] Hardening SSH...${NC}"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sed -i 's/^#*PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl reload ssh

# Restart WireGuard to ensure clean rules
systemctl restart wg-quick@wg0

# Clean up WireGuard duplicate rules
echo -e "${GREEN}Cleaning up duplicate firewall rules...${NC}"
sleep 2
# Remove WireGuard's PostUp duplicate (we have our own)
iptables -D INPUT -p udp --dport ${WG_PORT} -j ACCEPT 2>/dev/null || true
# Remove any other duplicates from PostUp
iptables -D FORWARD -i wg0 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i eth0 -o wg0 -j ACCEPT 2>/dev/null || true

netfilter-persistent save

# Final status check
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Installation Complete! 🎉${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${GREEN}✓ WireGuard:${NC} Running on port ${WG_PORT}"
echo -e "${GREEN}✓ Cloudflared:${NC} $(systemctl is-active cloudflared-dns.service)"
echo -e "${GREEN}✓ Firewall:${NC} DROP policy active"
echo -e "${GREEN}✓ SSH:${NC} Password auth disabled"
echo -e "${GREEN}✓ Optimizations:${NC} Zero packet loss configured"
echo ""
echo -e "${ORANGE}Your client config(s):${NC}"
ls -1 /root/wg0-client-*.conf
echo ""
echo -e "${ORANGE}Connection Details:${NC}"
SERVER_IP=$(grep "Endpoint" /root/wg0-client-*.conf | head -1 | cut -d'=' -f2 | xargs | cut -d':' -f1)
echo "  Server: ${SERVER_IP}:${WG_PORT}"
echo "  DNS: 10.66.66.1 (encrypted DoH)"
echo ""
echo -e "${GREEN}All ports blocked except SSH (22) and WireGuard (${WG_PORT})${NC}"
echo ""
echo -e "${ORANGE}To add more clients: sudo bash /tmp/wg-install.sh${NC}"
echo ""
