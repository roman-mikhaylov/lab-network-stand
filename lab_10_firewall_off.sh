#!/bin/bash
echo "=== Блок 10: Отключение файрвола на KVM-роутере ==="
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.17.10 \
  "sudo iptables -F FORWARD; sudo iptables -P FORWARD ACCEPT; sudo iptables -D INPUT -s 192.168.10.0/24 -d 192.168.10.1 -p tcp --dport 22 -j DROP 2>/dev/null; echo 'Файрвол сброшен'"
echo "OK"
