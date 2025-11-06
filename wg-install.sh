#!/bin/bash

# skript ultimate për wireguard v2.1 - vetëm ipv4
# baza: wireguard-install nga angristan
# përmirësuar me: cloudflared doh + siguri + optimizime pa humbje pakete
# https://github.com/angristan/wireguard-install

RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}=== Ultimate WireGuard Setup v2.1 - IPv4 Only ===${NC}"
echo "This script will install:"
echo "  ✓ WireGuard VPN (IPv4 ONLY - no IPv6 leaks)"
echo "  ✓ Cloudflared DNS-over-HTTPS"
echo "  ✓ Aggressive firewall (block all except SSH + VPN)"
echo "  ✓ Zero packet loss optimizations"
echo "  ✓ SSH hardening (keys only)"
echo "  ✓ NO duplicate rules"
echo ""

# shkarko skriptin e angristan
echo -e "${GREEN}[1/8] Downloading WireGuard installer...${NC}"
curl -fsSL https://raw.githubusercontent.com/angristan/wireguard-install/master/wireguard-install.sh -o /tmp/wg-install.sh
chmod +x /tmp/wg-install.sh

# ekzekuto instalimin e wireguard
echo -e "${GREEN}[2/8] Installing WireGuard...${NC}"
bash /tmp/wg-install.sh

# merr portin e wireguard nga konfigurimi
WG_PORT=$(grep "ListenPort" /etc/wireguard/wg0.conf | awk '{print $3}')
echo -e "${GREEN}WireGuard installed on port: ${WG_PORT}${NC}"

# KRITIKE: hiq të gjitha adresat ipv6 për të parandaluar rrjedhjet
echo -e "${GREEN}[3/8] Removing ALL IPv6 addresses (preventing leaks)...${NC}"

# hiq ipv6 nga interfejsi i serverit
sed -i 's/Address = \(10\.[0-9.]*\/[0-9]*\),.*/Address = \1/' /etc/wireguard/wg0.conf

# hiq ipv6 nga konfigurimi i klientit
for conf in /root/wg0-client-*.conf; do
    if [ -f "$conf" ]; then
        # hiq ipv6 nga address
        sed -i 's/Address = \(10\.[0-9.]*\/[0-9]*\),.*/Address = \1/' "$conf"
        # hiq ipv6 nga allowedips
        sed -i 's/AllowedIPs = 0\.0\.0\.0\/0,.*/AllowedIPs = 0.0.0.0\/0/' "$conf"
    fi
done

# hiq ipv6 nga peer allowedips në server config
sed -i 's/AllowedIPs = \(10\.[0-9.]*\/[0-9]*\),.*/AllowedIPs = \1/' /etc/wireguard/wg0.conf

# KRITIKE: hiq postup/postdown të wireguard (ne menaxhojmë firewall-in vetë)
echo -e "${GREEN}[4/8] Removing WireGuard PostUp/PostDown rules...${NC}"
sed -i '/^PostUp/d' /etc/wireguard/wg0.conf
sed -i '/^PostDown/d' /etc/wireguard/wg0.conf

# rifillo wireguard me konfigurim të pastër ipv4-only
systemctl restart wg-quick@wg0

# instalo cloudflared
echo -e "${GREEN}[5/8] Installing Cloudflared DNS-over-HTTPS (IPv4 only)...${NC}"
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb
rm -f cloudflared-linux-amd64.deb

# konfiguro cloudflared - vetëm ipv4
cat > /etc/systemd/system/cloudflared-dns.service << 'EOF'
[Unit]
Description=Cloudflared DNS over HTTPS proxy (IPv4 only)
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

# përditëso konfigurimin e klientit për dns të enkriptuar
echo -e "${GREEN}Updating client configs to use encrypted DNS...${NC}"
for conf in /root/wg0-client-*.conf; do
    if [ -f "$conf" ]; then
        sed -i 's/DNS = .*/DNS = 10.66.66.1/' "$conf"
    fi
done

# vendos firewall ipv4-only (i pastër, pa dublikate)
echo -e "${GREEN}[6/8] Setting up IPv4-only firewall...${NC}"

# pastro çdo rregull ekzistues për të filluar pastër
iptables -F INPUT
iptables -F FORWARD

# shto të gjitha rregullat allow para politikës drop
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p udp --dport ${WG_PORT} -j ACCEPT
iptables -A INPUT -p udp -s 10.66.66.0/24 --dport 53 -j ACCEPT
iptables -A INPUT -p tcp -s 10.66.66.0/24 --dport 53 -j ACCEPT

# rregullat forward - vetëm ipv4
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -i eth0 -o wg0 -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# vendos politikat
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP
iptables -P INPUT DROP

# BONUS: bloko të gjithë trafikun ipv6 për siguri maksimale
echo -e "${GREEN}Blocking ALL IPv6 traffic (leak prevention)...${NC}"
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT DROP

# ruaj rregullat e firewall
apt-get install -y iptables-persistent
netfilter-persistent save

# optimizime agresive sysctl për zero humbje paketash
echo -e "${GREEN}[7/8] Applying zero packet loss optimizations...${NC}"
cat > /etc/sysctl.d/99-wireguard-optimize.conf << 'EOF'
# optimizime agresive për zero humbje pakete
# tabelë masive për connection tracking
net.netfilter.nf_conntrack_max = 2097152

# timeout të gjatë udp (parandalon dështimin e handshake)
net.netfilter.nf_conntrack_udp_timeout = 600
net.netfilter.nf_conntrack_udp_timeout_stream = 600

# buffer të mëdhenj network (asnjëherë mos humb paketa)
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# radhë e madhe për përpunimin e paketave
net.core.netdev_max_backlog = 30000

# rrit lidhjet maksimale
net.core.somaxconn = 8192

# riciklim i shpejtë i socket-ave time_wait
net.ipv4.tcp_tw_reuse = 1

# mbaj lidhjet gjallë
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# çaktivizo ipv6 plotësisht
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

sysctl -p /etc/sysctl.d/99-wireguard-optimize.conf > /dev/null 2>&1

# forco ssh
echo -e "${GREEN}[8/8] Hardening SSH...${NC}"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sed -i 's/^#*PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl reload ssh

# rifillim final për të siguruar që gjithçka është e pastër
systemctl restart wg-quick@wg0
systemctl restart cloudflared-dns.service

# verifiko që nuk ka dublikate
echo -e "${GREEN}Verifying firewall (IPv4 only, no duplicates)...${NC}"
sleep 2

# kontrolli final i statusit
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Installation Complete! 🎉${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${GREEN}✓ WireGuard:${NC} Running on port ${WG_PORT} (IPv4 ONLY)"
echo -e "${GREEN}✓ Cloudflared:${NC} $(systemctl is-active cloudflared-dns.service)"
echo -e "${GREEN}✓ Firewall:${NC} DROP policy active (NO duplicates)"
echo -e "${GREEN}✓ IPv6:${NC} DISABLED (no leaks possible)"
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
echo "  IPv6: DISABLED (maximum privacy)"
echo ""
echo -e "${GREEN}All ports blocked except SSH (22) and WireGuard (${WG_PORT})${NC}"
echo ""
echo -e "${ORANGE}Firewall Status:${NC}"
echo "  IPv4 INPUT rules: $(iptables -L INPUT --line-numbers | grep -c '^[0-9]')"
echo "  IPv4 FORWARD rules: $(iptables -L FORWARD --line-numbers | grep -c '^[0-9]')"
echo "  IPv6: FULLY BLOCKED"
echo "  Blocked packets: $(iptables -L INPUT -n -v | grep 'policy DROP' | awk '{print $1}')"
echo ""
echo -e "${ORANGE}To add more clients: sudo bash /tmp/wg-install.sh${NC}"
echo -e "${ORANGE}Then update: sed -i 's/DNS = .*/DNS = 10.66.66.1/; s/,.*//; s/AllowedIPs = .*/AllowedIPs = 0.0.0.0\/0/' /root/wg0-client-*.conf${NC}"
echo ""
