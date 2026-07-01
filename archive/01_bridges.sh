#!/bin/bash
echo "============================================"
echo " ШАГ 01: Создание мостов и базовых сетей"
echo "============================================"

# Мосты
sudo ip link add br-lan-a type bridge && sudo ip link set br-lan-a up
sudo ip link add br-lan-b type bridge && sudo ip link set br-lan-b up
sudo ip link add br-wan type bridge && sudo ip link set br-wan up
sudo ip link add br-transit type bridge && sudo ip link set br-transit up

# IP на WAN-мосту (хост как шлюз для KVM-роутера)
sudo ip addr add 192.168.17.1/24 dev br-wan
sudo ip addr add 192.168.10.1/24 dev br-lan-a

# NAT на хосте для выхода в интернет
sudo iptables -t nat -A POSTROUTING -s 192.168.17.0/24 ! -d 192.168.17.0/24 -j MASQUERADE
sudo sysctl -w net.ipv4.ip_forward=1

# Диагностика
echo ""
echo "РЕЗУЛЬТАТ:"
echo "  Созданы мосты:"
echo "    br-lan-a   — сеть LAN-A (192.168.10.0/24)"
echo "    br-lan-b   — сеть LAN-B (192.168.20.0/24)"
echo "    br-wan     — внешняя сеть (192.168.17.0/24)"
echo "    br-transit — транзитная сеть (10.10.12.0/30)"
echo ""
echo "  IP-адреса хоста:"
echo "    192.168.17.1/24 на br-wan (шлюз для KVM-роутера)"
echo "    192.168.10.1/24 на br-lan-a (шлюз для LAN-A)"
echo ""
echo "  NAT на хосте: включён для 192.168.17.0/24"
echo "  IP Forwarding: включён"
echo ""
echo "  Проверка мостов:"
for BR in br-lan-a br-lan-b br-wan br-transit; do
    ip link show $BR | grep -q UP && echo "    $BR: UP" || echo "    $BR: ОШИБКА"
done
echo "OK"
