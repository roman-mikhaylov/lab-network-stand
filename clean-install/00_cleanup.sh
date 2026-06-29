#!/bin/bash
echo "============================================"
echo " ШАГ 00: Полная очистка системы"
echo "============================================"

sudo pkill -9 -f dhcpd 2>/dev/null || true
sudo pkill -9 -f dhclient 2>/dev/null || true
sudo pkill -9 -f zebra 2>/dev/null || true
sudo pkill -9 -f ospfd 2>/dev/null || true

for VM in kvm-router org-server samba-server; do
    sudo virsh destroy $VM 2>/dev/null || true
    sudo virsh undefine $VM --remove-all-storage 2>/dev/null || true
done

for NS in pc-a pc-b r2; do
    sudo ip netns del $NS 2>/dev/null || true
done

for BR in br-lan-a br-lan-b br-wan br-transit; do
    sudo ip link del $BR 2>/dev/null || true
done

sudo iptables -F
sudo iptables -t nat -F
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT

echo ""
echo "РЕЗУЛЬТАТ:"
echo "  - Все виртуальные машины удалены"
echo "  - Все network namespaces удалены"
echo "  - Все мосты удалены"
echo "  - iptables сброшены (всё открыто)"
echo "  - Система готова к чистой установке"
echo "OK"
