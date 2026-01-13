# wireguard installer

ky projekt eshte nje bash script qe te ben setup te nje wireguard vpn server ne linux sa me kollaj qe te mundesht

## cfar eshte wireguard

wireguard eshte nje vpn moderne dhe shume i shpejt qe punon ne nivelin e kernelit

me kete script klienti do te dergoj te gjith trafikun e tij nepermjet nje tuneli te enkriptuar ne server dhe serveri do ta rout ate trafik me nat keshtu qe do te duket sikur klienti po ban browse me ip te serverit

skripti suporton edhe ipv4 edhe ipv6

## kerkesa

sisteme operative te suportuara:

- almalinux >= 8
- alpine linux
- arch linux
- centos stream >= 8
- debian >= 10
- fedora >= 32
- oracle linux
- rocky linux >= 8
- ubuntu >= 18.04

## perdorimi

shkarko dhe ekzekuto skriptin dhe pergjigju pyetjeve

```bash
curl -O https://raw.githubusercontent.com/alban-hh/wireguard-install/master/wireguard-install.sh
chmod +x wireguard-install.sh
./wireguard-install.sh
```

do te instaloj wireguard ne server do ta konfiguron do te krijoj nje systemd service dhe nje file konfigurimi per klientin

ekzekuto skriptin perseri per te shtuar ose larguar klienta

## provajdera te rekomanduar

disa provajdera te lire dhe te mire per vpn server:

- vultr me lokacione neper bote ipv6 support nga $5 ne muaj
- hetzner ne gjermani finlande dhe usa me ipv6 dhe 20 tb trafik nga 4.5 euro ne muaj
- digital ocean me lokacione neper bote ipv6 support nga $4 ne muaj

## kontribut

kontributet jan te mirepritura

### diskuto ndryshimet

hap nje issue para se te besh pull request nese don me diskutu ndonje ndryshim te madh

### formatimi i kodit

perdorim shellcheck dhe shfmt per te garantuar qe kodi bash eshte i shkruar mire

## licence

ky projekt eshte nen licence mit
