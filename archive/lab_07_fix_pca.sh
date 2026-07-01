#!/bin/bash
echo "=== Ручное исправление PC-A ==="
sudo ip addr flush dev pc-a-eth 2>/dev/null || true
sudo ip netns exec pc-a ip addr flush dev pc-a-eth 2>/dev/null || true
sudo ip netns exec pc-a dhclient pc-a-eth 2>/dev/null
sleep 3
PC_A_IP=$(sudo ip netns exec pc-a ip addr show pc-a-eth | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
if [ -z "$PC_A_IP" ]; then
    sleep 5
    PC_A_IP=$(sudo ip netns exec pc-a ip addr show pc-a-eth | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
fi
sudo ip netns exec pc-a ip route add default via 192.168.10.1 2>/dev/null || true
sudo ip netns exec pc-a ip route add 192.168.20.0/24 via 192.168.10.1 2>/dev/null || true
[ -n "$PC_A_IP" ] && echo "PC-A IP: $PC_A_IP - OK" || echo "PC-A IP: нет - ОШИБКА"
