#!/bin/bash
# Поднимаем интерфейсы (IP заданы в конфигах FRR, но для верности)
ip addr add 10.10.12.2/30 dev eth0 2>/dev/null || true
ip addr add 192.168.20.1/24 dev eth1 2>/dev/null || true
ip link set eth0 up
ip link set eth1 up

# Включаем форвардинг
sysctl -w net.ipv4.ip_forward=1

# Запускаем FRR
/usr/lib/frr/frrinit.sh start

# Запускаем DHCP на eth1
sed -i 's/INTERFACESv4=""/INTERFACESv4="eth1"/' /etc/default/isc-dhcp-server
/usr/sbin/dhcpd -4 -f -d eth1 &

# Держим контейнер живым
tail -f /dev/null
