#!/bin/bash
echo "=== Блок 2: Мосты и NAT ==="
sudo ip link add br-lan-a type bridge 2>/dev/null || true
sudo ip link add br-lan-b type bridge 2>/dev/null || true
sudo ip link add br-wan type bridge 2>/dev/null || true
sudo ip link add br-transit type bridge 2>/dev/null || true
sudo ip link set br-lan-a up
sudo ip link set br-lan-b up
sudo ip link set br-wan up
sudo ip link set br-transit up
sudo ip addr add 192.168.17.1/24 dev br-wan 2>/dev/null || true
sudo iptables -t nat -C POSTROUTING -s 192.168.17.0/24 ! -d 192.168.17.0/24 -j MASQUERADE 2>/dev/null || \
sudo iptables -t nat -A POSTROUTING -s 192.168.17.0/24 ! -d 192.168.17.0/24 -j MASQUERADE
sudo sysctl -w net.ipv4.ip_forward=1
echo "OK"
