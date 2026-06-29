#!/bin/bash
echo "============================================"
echo " ШАГ 03: Подключение клиентов PC-A и PC-B"
echo "============================================"

# PC-A -> LAN-A
sudo ip link add pc-a-eth type veth peer name lan-a-port1
sudo ip link set pc-a-eth netns pc-a
sudo ip link set lan-a-port1 master br-lan-a
sudo ip link set lan-a-port1 up
sudo ip netns exec pc-a ip link set lo up
sudo ip netns exec pc-a ip link set pc-a-eth up

# PC-B -> LAN-B
sudo ip link add pc-b-eth type veth peer name lan-b-port1
sudo ip link set pc-b-eth netns pc-b
sudo ip link set lan-b-port1 master br-lan-b
sudo ip link set lan-b-port1 up
sudo ip netns exec pc-b ip link set lo up
sudo ip netns exec pc-b ip link set pc-b-eth up

echo ""
echo "РЕЗУЛЬТАТ:"
echo "  PC-A подключён к br-lan-a (сеть 192.168.10.0/24)"
echo "  PC-B подключён к br-lan-b (сеть 192.168.20.0/24)"
echo "  Интерфейсы подняты, IP будут получены по DHCP позже"
echo ""
echo "  Проверка интерфейсов:"
sudo ip netns exec pc-a ip link show pc-a-eth | grep -q UP && echo "    pc-a-eth: UP" || echo "    pc-a-eth: ОШИБКА"
sudo ip netns exec pc-b ip link show pc-b-eth | grep -q UP && echo "    pc-b-eth: UP" || echo "    pc-b-eth: ОШИБКА"
echo "OK"
