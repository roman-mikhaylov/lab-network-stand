#!/bin/bash
echo "============================================"
echo " ФИКС: Восстановление сети после сбоя"
echo "============================================"

echo "1. Перезапуск DHCP на Router2..."
sudo ip netns exec r2 dhcpd -4 -cf /etc/dhcp/dhcpd.conf -lf /var/lib/dhcp/dhcpd.leases -f r2-eth1 &>/dev/null &
sleep 3

echo "2. Запрос IP для PC-A и PC-B..."
sudo ip netns exec pc-a dhclient pc-a-eth 2>/dev/null &
sudo ip netns exec pc-b dhclient pc-b-eth 2>/dev/null &
sleep 5

echo "3. Добавление правил iptables на KVM-роутере..."
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.17.10 \
  "sudo iptables -A FORWARD -i enp3s0 -o enp2s0 -j ACCEPT 2>/dev/null; \
   sudo iptables -A FORWARD -i enp2s0 -o enp3s0 -j ACCEPT 2>/dev/null; \
   sudo iptables -A FORWARD -i enp3s0 -o enp1s0 -j ACCEPT 2>/dev/null; \
   sudo iptables -A FORWARD -i enp2s0 -o enp1s0 -j ACCEPT 2>/dev/null; \
   sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null"

echo "4. Добавление маршрутов..."
sudo ip netns exec pc-a ip route add 192.168.20.0/24 via 192.168.10.1 2>/dev/null || true
sudo ip netns exec pc-b ip route add default via 192.168.20.1 2>/dev/null || true
sudo ip netns exec pc-b ip route add 192.168.10.0/24 via 192.168.20.1 2>/dev/null || true

echo ""
echo "5. Проверка связи..."
./08_check.sh
