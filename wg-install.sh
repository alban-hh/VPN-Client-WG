#!/bin/bash

# skript ultimate për wireguard v2.3 - ubuntu 24.04 optimized
# baza: wireguard-install nga angristan
# përmirësuar me: cloudflared doh + siguri + optimizime pa humbje pakete
# v2.3: multiple failproof methods, ubuntu 24.04 optimized
# https://github.com/alban-hh/VPN-Client-WG

RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# kontrollo root permissions
if [ "$EUID" -ne 0 ]; then 
   echo -e "${RED}Error: Duhet të ekzekutosh si root (sudo)${NC}"
   exit 1
fi

echo -e "${GREEN}=== Ultimate WireGuard Setup v2.3 ===${NC}"
echo -e "${BLUE}Optimized for Ubuntu 24.04 64-bit${NC}"
echo ""

# kontrollo os dhe version (ubuntu 24.04 e kërkuar)
echo -e "${GREEN}[1/12] Checking OS and version...${NC}"

if [ ! -f /etc/os-release ]; then
    echo -e "${RED}Error: Cannot detect OS. /etc/os-release not found.${NC}"
    exit 1
fi

source /etc/os-release

if [ "$ID" != "ubuntu" ]; then
    echo -e "${ORANGE}Warning: This script is optimized for Ubuntu 24.04${NC}"
    echo -e "${ORANGE}Current OS: $ID${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
elif [ "$VERSION_ID" != "24.04" ]; then
    echo -e "${ORANGE}Warning: This script is optimized for Ubuntu 24.04${NC}"
    echo -e "${ORANGE}Current version: $VERSION_ID${NC}"
    echo -e "${ORANGE}Continuing anyway...${NC}"
fi

echo -e "${GREEN}✓ OS Check: $ID $VERSION_ID${NC}"

# kontrollo arkitekturën (64-bit e kërkuar)
echo -e "${GREEN}[2/12] Checking architecture...${NC}"
ARCH=$(uname -m)

if [ "$ARCH" != "x86_64" ]; then
    echo -e "${RED}Error: This script requires 64-bit (x86_64)${NC}"
    echo -e "${RED}Current architecture: $ARCH${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Architecture: $ARCH (64-bit)${NC}"

# auto-detect public network interface (multiple methods)
echo -e "${GREEN}[3/12] Auto-detecting public network interface (multiple methods)...${NC}"

# metoda 1: default route
PUBLIC_NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

# metoda 2: nëse metoda 1 dështon
if [ -z "$PUBLIC_NIC" ]; then
    PUBLIC_NIC=$(ip -4 addr show | grep -v "127.0.0.1" | grep "inet " | awk '{print $NF}' | head -1)
fi

# metoda 3: kontrollo interface të zakonshme për ubuntu 24.04
if [ -z "$PUBLIC_NIC" ]; then
    for iface in eth0 ens3 ens4 ens5 enp0s3 enp0s8; do
        if ip addr show "$iface" >/dev/null 2>&1; then
            PUBLIC_NIC="$iface"
            break
        fi
    done
fi

# validim final
if [ -z "$PUBLIC_NIC" ]; then
    echo -e "${RED}Error: Could not auto-detect public network interface!${NC}"
    echo -e "${ORANGE}Available interfaces:${NC}"
    ip -4 addr show | grep -E "^[0-9]+:" | awk '{print $2}' | tr -d ':'
    echo ""
    read -p "Enter interface name manually: " PUBLIC_NIC
    
    if [ -z "$PUBLIC_NIC" ]; then
        echo -e "${RED}Error: No interface specified. Exiting.${NC}"
        exit 1
    fi
fi

# validim që interface ekziston dhe ka ip
if ! ip addr show "$PUBLIC_NIC" >/dev/null 2>&1; then
    echo -e "${RED}Error: Interface $PUBLIC_NIC does not exist!${NC}"
    exit 1
fi

if ! ip addr show "$PUBLIC_NIC" | grep -q "inet "; then
    echo -e "${RED}Error: Interface $PUBLIC_NIC has no IPv4 address!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Detected public interface: ${PUBLIC_NIC}${NC}"

# kontrollo konektivitetin në internet
echo -e "${GREEN}[4/12] Checking internet connectivity...${NC}"

if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
    echo -e "${RED}Error: No internet connection detected!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Internet connectivity: OK${NC}"

# shkarko skriptin e angristan
echo -e "${GREEN}[5/12] Downloading WireGuard installer...${NC}"

if ! curl -fsSL https://raw.githubusercontent.com/angristan/wireguard-install/master/wireguard-install.sh -o /tmp/wg-install.sh; then
    echo -e "${RED}Error: Failed to download WireGuard installer!${NC}"
    exit 1
fi

chmod +x /tmp/wg-install.sh
echo -e "${GREEN}✓ Installer downloaded${NC}"

# ekzekuto instalimin e wireguard
echo -e "${GREEN}[6/12] Installing WireGuard...${NC}"
echo -e "${ORANGE}Please answer the installer questions...${NC}"
echo ""

bash /tmp/wg-install.sh

# validim që wireguard u instalua
if [ ! -f /etc/wireguard/wg0.conf ]; then
    echo -e "${RED}Error: WireGuard installation failed or was cancelled!${NC}"
    exit 1
fi

# merr portin e wireguard nga konfigurimi
WG_PORT=$(grep "ListenPort" /etc/wireguard/wg0.conf | awk '{print $3}')

if [ -z "$WG_PORT" ]; then
    echo -e "${RED}Error: Could not detect WireGuard port!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ WireGuard installed on port: ${WG_PORT}${NC}"

# backup i konfigurimit origjinal
echo -e "${GREEN}[7/12] Backing up original configuration...${NC}"
cp /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.backup-$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}✓ Backup created${NC}"

# KRITIKE: hiq të gjitha adresat ipv6 për të parandaluar rrjedhjet
echo -e "${GREEN}[8/12] Removing ALL IPv6 addresses (preventing leaks)...${NC}"

# hiq ipv6 nga interfejsi i serverit
sed -i 's/Address = \(10\.[0-9.]*\/[0-9]*\),.*/Address = \1/' /etc/wireguard/wg0.conf

# hiq ipv6 nga konfigurimi i klientit
for conf in /root/wg0-client-*.conf; do
    if [ -f "$conf" ]; then
        sed -i 's/Address = \(10\.[0-9.]*\/[0-9]*\),.*/Address = \1/' "$conf"
        sed -i 's/AllowedIPs = 0\.0\.0\.0\/0,.*/AllowedIPs = 0.0.0.0\/0/' "$conf"
    fi
done

# hiq ipv6 nga peer allowedips në server config
sed -i 's/AllowedIPs = \(10\.[0-9.]*\/[0-9]*\),.*/AllowedIPs = \1/' /etc/wireguard/wg0.conf

# hiq postup/postdown (ne menaxhojmë firewall-in vetë)
sed -i '/^PostUp/d' /etc/wireguard/wg0.conf
sed -i '/^PostDown/d' /etc/wireguard/wg0.conf

echo -e "${GREEN}✓ IPv6 removed from all configs${NC}"

# instalo cloudflared
echo -e "${GREEN}[9/12] Installing Cloudflared DNS-over-HTTPS...${NC}"

if ! wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb; then
    echo -e "${RED}Error: Failed to download Cloudflared!${NC}"
    exit 1
fi

if ! dpkg -i cloudflared-linux-amd64.deb; then
    echo -e "${RED}Error: Failed to install Cloudflared!${NC}"
    exit 1
fi

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
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cloudflared-dns.service

# përditëso konfigurimin e klientit për dns të enkriptuar
for conf in /root/wg0-client-*.conf; do
    if [ -f "$conf" ]; then
        sed -i 's/DNS = .*/DNS = 10.66.66.1/' "$conf"
    fi
done

echo -e "${GREEN}✓ Cloudflared installed and configured${NC}"

# vendos firewall ipv4-only
echo -e "${GREEN}[10/12] Setting up IPv4-only firewall with interface ${PUBLIC_NIC}...${NC}"

# pastro çdo rregull ekzistues për të filluar pastër
iptables -F INPUT 2>/dev/null || true
iptables -F FORWARD 2>/dev/null || true
iptables -t nat -F POSTROUTING 2>/dev/null || true

# shto të gjitha rregullat allow para politikës drop
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p udp --dport ${WG_PORT} -j ACCEPT
iptables -A INPUT -p udp -s 10.66.66.0/24 --dport 53 -j ACCEPT
iptables -A INPUT -p tcp -s 10.66.66.0/24 --dport 53 -j ACCEPT

# rregullat forward me interface të detektuar
iptables -A FORWARD -i wg0 -o ${PUBLIC_NIC} -j ACCEPT
iptables -A FORWARD -i ${PUBLIC_NIC} -o wg0 -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# NAT/MASQUERADE (zëvendëson postup të wireguard)
iptables -t nat -A POSTROUTING -o ${PUBLIC_NIC} -j MASQUERADE

# vendos politikat
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP
iptables -P INPUT DROP

# bloko të gjithë trafikun ipv6
ip6tables -P INPUT DROP 2>/dev/null || true
ip6tables -P FORWARD DROP 2>/dev/null || true
ip6tables -P OUTPUT DROP 2>/dev/null || true

# instalo iptables-persistent nëse nuk ekziston
if ! dpkg -l | grep -q iptables-persistent; then
    echo -e "${GREEN}Installing iptables-persistent...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
fi

# ruaj rregullat
netfilter-persistent save

echo -e "${GREEN}✓ Firewall configured (IPv4 only, interface: ${PUBLIC_NIC})${NC}"

# optimizime sysctl për zero humbje paketash
echo -e "${GREEN}[11/12] Applying zero packet loss optimizations...${NC}"

cat > /etc/sysctl.d/99-wireguard-optimize.conf << EOF
# optimizime agresive për zero humbje pakete
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_udp_timeout = 600
net.netfilter.nf_conntrack_udp_timeout_stream = 600
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.core.netdev_max_backlog = 30000
net.core.somaxconn = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.${PUBLIC_NIC}.disable_ipv6 = 1
net.ipv6.conf.wg0.disable_ipv6 = 1
EOF

sysctl -p /etc/sysctl.d/99-wireguard-optimize.conf > /dev/null 2>&1

echo -e "${GREEN}✓ Optimizations applied${NC}"

# forco ssh
echo -e "${GREEN}[12/12] Hardening SSH...${NC}"

if [ ! -f /etc/ssh/sshd_config.backup ]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
fi

sed -i 's/^#*PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# validim që ka ssh keys para se të çaktivizojmë passwords
if [ ! -f ~/.ssh/authorized_keys ] || [ ! -s ~/.ssh/authorized_keys ]; then
    echo -e "${ORANGE}Warning: No SSH keys found in ~/.ssh/authorized_keys${NC}"
    echo -e "${ORANGE}Skipping SSH password disable for safety.${NC}"
    sed -i 's/^PasswordAuthentication no/#PasswordAuthentication yes/' /etc/ssh/sshd_config
else
    systemctl reload ssh
    echo -e "${GREEN}✓ SSH hardened (keys only)${NC}"
fi

# rifillo shërbimet
echo -e "${GREEN}Restarting services...${NC}"
systemctl restart wg-quick@wg0
systemctl start cloudflared-dns.service

# validim final
echo -e "${GREEN}Running final validation...${NC}"
sleep 3

# kontrollo që wireguard funksionon
if ! systemctl is-active --quiet wg-quick@wg0; then
    echo -e "${RED}Error: WireGuard service is not running!${NC}"
    exit 1
fi

# kontrollo që cloudflared funksionon
if ! systemctl is-active --quiet cloudflared-dns.service; then
    echo -e "${ORANGE}Warning: Cloudflared not running, attempting restart...${NC}"
    systemctl restart cloudflared-dns.service
    sleep 2
fi

# kontrollo që nat ekziston
NAT_CHECK=$(iptables -t nat -L POSTROUTING -n | grep -c MASQUERADE)
if [ "$NAT_CHECK" -eq 0 ]; then
    echo -e "${RED}ERROR: NAT/MASQUERADE not configured!${NC}"
    exit 1
fi

# shfaq rezultatet finale
echo ""
echo -e "${GREEN}════════════════════════════════${NC}"
echo -e "${GREEN}  Installation Complete! 🎉${NC}"
echo -e "${GREEN}════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}System Information:${NC}"
echo "  OS: Ubuntu $VERSION_ID 64-bit"
echo "  Interface: $PUBLIC_NIC"
echo ""
echo -e "${BLUE}Service Status:${NC}"
echo "  ✓ WireGuard: Running on port ${WG_PORT} (IPv4 ONLY)"
echo "  ✓ Cloudflared: $(systemctl is-active cloudflared-dns.service)"
echo "  ✓ NAT: MASQUERADE on ${PUBLIC_NIC}"
echo "  ✓ Firewall: DROP policy active"
echo "  ✓ IPv6: FULLY DISABLED"
echo "  ✓ SSH: $(grep -q '^PasswordAuthentication no' /etc/ssh/sshd_config && echo 'Keys only' || echo 'Password enabled')"
echo ""
echo -e "${ORANGE}Client Configuration(s):${NC}"
ls -1 /root/wg0-client-*.conf
echo ""
SERVER_IP=$(grep "Endpoint" /root/wg0-client-*.conf 2>/dev/null | head -1 | cut -d'=' -f2 | xargs | cut -d':' -f1)
echo -e "${ORANGE}Connection Details:${NC}"
echo "  Server: ${SERVER_IP}:${WG_PORT}"
echo "  DNS: 10.66.66.1 (encrypted DoH)"
echo "  IPv6: DISABLED (no leaks)"
echo ""
echo -e "${ORANGE}Firewall Rules:${NC}"
echo "  INPUT: $(iptables -L INPUT --line-numbers | grep -c '^[0-9]') rules"
echo "  FORWARD: $(iptables -L FORWARD --line-numbers | grep -c '^[0-9]') rules"
echo "  NAT: $(iptables -t nat -L POSTROUTING --line-numbers | grep -c '^[0-9]') rules"
echo ""
echo -e "${ORANGE}Backups:${NC}"
ls -1 /etc/wireguard/*.backup* 2>/dev/null | head -3
echo ""
echo -e "${GREEN}To add more clients:${NC} sudo bash /tmp/wg-install.sh"
echo -e "${GREEN}Then update DNS:${NC} sed -i 's/DNS = .*/DNS = 10.66.66.1/' /root/wg0-client-*.conf"
echo ""
