#!/bin/bash
echo "============================================"
echo " ШАГ 01: Создание мостов и базовых сетей"
echo "============================================"

sudo ip link add br-lan-a type bridge && sudo ip link set br-lan-a up
sudo ip link add br-lan-b type bridge && sudo ip link set br-lan-b up
sudo ip link add br-wan type bridge && sudo ip link set br-wan up
sudo ip link add br-transit type bridge && sudo ip link set br-transit up

sudo ip addr add 192.168.17.1/24 dev br-wan
sudo ip addr add 192.168.10.1/24 dev br-lan-a

sudo iptables -t nat -A POSTROUTING -s 192.168.17.0/24 ! -d 192.168.17.0/24 -j MASQUERADE
sudo sysctl -w net.ipv4.ip_forward=1

echo ""
echo "РЕЗУЛЬТАТ:"
echo "  Мосты созданы:"
echo "    br-lan-a   — 192.168.10.0/24 (LAN-A)"
echo "    br-lan-b   — 192.168.20.0/24 (LAN-B)"
echo "    br-wan     — 192.168.17.0/24 (WAN)"
echo "    br-transit — 10.10.12.0/30 (Transit)"
echo "  IP хоста: 192.168.17.1 (WAN), 192.168.10.1 (LAN-A)"
echo "  NAT включён, форвардинг включён"
echo "OK"
