#!/bin/bash
echo "============================================"
echo " ШАГ 08: Ожидание OSPF и проверка связи"
echo "============================================"

echo "  Ожидание установления OSPF (20 секунд)..."
sleep 20

# Убедимся, что маршруты есть
sudo ip netns exec pc-a ip route add 192.168.20.0/24 via 192.168.10.1 2>/dev/null || true
sudo ip netns exec pc-b ip route add default via 192.168.20.1 2>/dev/null || true
sudo ip netns exec pc-b ip route add 192.168.10.0/24 via 192.168.20.1 2>/dev/null || true

echo ""
echo "РЕЗУЛЬТАТ:"
PC_B=$(sudo ip netns exec pc-b ip addr show pc-b-eth | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
echo "  PC-A -> PC-B ($PC_B):"
sudo ip netns exec pc-a ping -c 2 -W 2 $PC_B >/dev/null 2>&1 && echo "    OK" || echo "    НЕТ"
echo "  PC-A -> Интернет (8.8.8.8):"
sudo ip netns exec pc-a ping -c 2 -W 2 8.8.8.8 >/dev/null 2>&1 && echo "    OK" || echo "    НЕТ"
echo "OK"
