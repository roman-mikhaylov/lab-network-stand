#!/bin/bash
echo "============================================"
echo " ШАГ 08: Проверка связи"
echo "============================================"

PC_B=$(sudo ip netns exec pc-b ip addr show pc-b-eth | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

echo "  PC-A -> PC-B ($PC_B):"
sudo ip netns exec pc-a ping -c 2 -W 2 $PC_B >/dev/null 2>&1 && echo "    OK" || echo "    НЕТ"

echo "  PC-A -> Интернет (8.8.8.8):"
sudo ip netns exec pc-a ping -c 2 -W 2 8.8.8.8 >/dev/null 2>&1 && echo "    OK" || echo "    НЕТ"

echo "OK"
