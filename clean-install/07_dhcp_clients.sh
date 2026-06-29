#!/bin/bash
echo "============================================"
echo " ШАГ 07: Выдача DHCP клиентам"
echo "============================================"

sudo ip netns exec pc-a dhclient pc-a-eth 2>/dev/null &
sudo ip netns exec pc-b dhclient pc-b-eth 2>/dev/null &
sleep 5

sudo ip netns exec pc-a ip route add default via 192.168.10.1 2>/dev/null || true
sudo ip netns exec pc-b ip route add default via 192.168.20.1 2>/dev/null || true

echo ""
echo "РЕЗУЛЬТАТ:"
PC_A=$(sudo ip netns exec pc-a ip addr show pc-a-eth | grep 'inet ' | awk '{print $2}')
PC_B=$(sudo ip netns exec pc-b ip addr show pc-b-eth | grep 'inet ' | awk '{print $2}')
echo "  PC-A: $PC_A"
echo "  PC-B: $PC_B"
[ -n "$PC_A" ] && echo "  PC-A IP: OK" || echo "  PC-A IP: ОШИБКА"
[ -n "$PC_B" ] && echo "  PC-B IP: OK" || echo "  PC-B IP: ОШИБКА"
echo "OK"
