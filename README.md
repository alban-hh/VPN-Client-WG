# WireGuard Installer

[![CI](https://github.com/alban-hh/VPN-Client-WG/actions/workflows/ci.yml/badge.svg)](https://github.com/alban-hh/VPN-Client-WG/actions/workflows/ci.yml)
![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=white)
![WireGuard](https://img.shields.io/badge/WireGuard-88171A?logo=wireguard&logoColor=white)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

An interactive Bash script that turns a fresh Linux server into a WireGuard VPN server and manages its clients.

## What it does

- Installs WireGuard and its tools with the package manager of your distribution
- Generates server keys, picks a random port and writes the interface config
- Sets up NAT and forwarding through iptables or firewalld, for IPv4 and IPv6
- Creates client configs with preshared keys and prints them as QR codes
- Adds, lists and revokes clients, or removes WireGuard entirely, on later runs

## Supported systems

AlmaLinux 8+, Alpine Linux, Arch Linux, CentOS Stream 8+, Debian 10+, Fedora 32+, Oracle Linux, Rocky Linux 8+ and Ubuntu 18.04+. OpenVZ and LXC are not supported.

## Usage

```bash
curl -O https://raw.githubusercontent.com/alban-hh/VPN-Client-WG/main/wireguard-install.sh
chmod +x wireguard-install.sh
sudo ./wireguard-install.sh
```

Answer the prompts and the script installs WireGuard, enables the service and creates the first client. Run it again to add, list or revoke clients. Client config files are written to the home directory of the invoking user.

## Development

```bash
shellcheck wireguard-install.sh
shfmt -d wireguard-install.sh
```

Both run in CI on every push.

## License

MIT
