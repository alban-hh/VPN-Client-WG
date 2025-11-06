# 🔒 Ultimate WireGuard VPN Setup

One-command installation of a secure, high-performance WireGuard VPN server with encrypted DNS and zero packet loss.

## ✨ Features

- **🔐 Maximum Security**: Blocks all ports except SSH + VPN, SSH keys only
- **🔒 DNS-over-HTTPS**: Encrypted DNS via Cloudflare (no DNS leaks)
- **🚀 Zero Packet Loss**: Optimized for stable connections, no disconnects
- **⚡ High Performance**: 2M connection tracking, 10min UDP timeouts, 256MB buffers
- **🎯 Easy Setup**: Single command installation on fresh Ubuntu servers

## 🚀 Quick Start

```bash
curl -O https://raw.githubusercontent.com/alban-hh/Office-VPN-Client-WG/main/wg-install.sh
chmod +x wg-install.sh
sudo ./wg-install.sh
```

**Requirements:** Fresh Ubuntu 20.04+ server with root access

## 📦 What Gets Installed

1. **WireGuard VPN** - Modern, fast VPN protocol
2. **Cloudflared** - DNS-over-HTTPS proxy (encrypted DNS)
3. **iptables Firewall** - Blocks all ports except SSH (22) and VPN
4. **Sysctl Optimizations** - Zero packet loss configuration
5. **SSH Hardening** - Password auth disabled

## 🔧 Configuration

The script will ask you:
- Server IP address (auto-detected)
- VPN port (random 49152-65535)
- First client name
- Press Enter for all defaults

## 📱 Client Setup

After installation, find your client config:
```bash
cat /root/wg0-client-*.conf
```

**Windows/Mac/Linux:** Import the `.conf` file into WireGuard app

**Mobile:** Scan the QR code shown at the end

## 🛡️ Security Features

- ✅ All ports blocked except SSH + VPN
- ✅ Password authentication disabled (SSH keys only)
- ✅ DNS encrypted via Cloudflare 1.1.1.1
- ✅ No DNS leaks
- ✅ DROP policy firewall

## ⚡ Performance Optimizations

- 2,097,152 max connections
- 600 second UDP timeout (prevents disconnects)
- 256MB network buffers
- 30,000 packet queue
- TCP BBR congestion control

## 🔄 Adding More Clients

```bash
sudo bash /tmp/wg-install.sh
```

Select "Add a new user" from the menu.

## 📊 Verify Installation

```bash
# Check WireGuard status
sudo wg show

# Check firewall
sudo iptables -L -n -v

# Check Cloudflared
sudo systemctl status cloudflared-dns.service
```

## 🆘 Support

Open an issue if you encounter problems.

## 📄 License

MIT License - Free to use and modify.
