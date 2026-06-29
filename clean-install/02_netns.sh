#!/bin/bash
echo "============================================"
echo " ШАГ 02: Создание network namespaces и DNS"
echo "============================================"

sudo ip netns add pc-a
sudo ip netns add pc-b
sudo ip netns add r2

sudo mkdir -p /etc/netns/pc-a /etc/netns/pc-b /etc/netns/r2
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/pc-a/resolv.conf >/dev/null
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/pc-b/resolv.conf >/dev/null
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/r2/resolv.conf >/dev/null

echo ""
echo "РЕЗУЛЬТАТ:"
echo "  Созданы network namespaces:"
echo "    pc-a — клиент в LAN-A (192.168.10.0/24)"
echo "    pc-b — клиент в LAN-B (192.168.20.0/24)"
echo "    r2   — Router2 (маршрутизатор)"
echo "  DNS 8.8.8.8 прописан для всех namespaces"
echo ""
echo "  Проверка:"
ip netns list
echo "OK"
