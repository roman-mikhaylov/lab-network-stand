#!/bin/bash
set -e

echo "=== Создание bridge ==="
sudo ip link add br-lan-a type bridge
sudo ip link add br-lan-b type bridge
sudo ip link add br-wan type bridge
sudo ip link set br-lan-a up
sudo ip link set br-lan-b up
sudo ip link set br-wan up
sudo ip addr add 192.168.17.1/24 dev br-wan

echo "=== Создание network namespaces ==="
sudo ip netns add pc-a
sudo ip netns add pc-b
sudo ip netns add r1
sudo ip netns add r2

echo "=== PC-A → LAN-A ==="
sudo ip link add pc-a-eth type veth peer name lan-a-port1
sudo ip link set pc-a-eth netns pc-a
sudo ip link set lan-a-port1 master br-lan-a
sudo ip link set lan-a-port1 up
sudo ip netns exec pc-a ip addr add 192.168.10.10/24 dev pc-a-eth
sudo ip netns exec pc-a ip link set lo up
sudo ip netns exec pc-a ip link set pc-a-eth up
sudo ip netns exec pc-a ip route add default via 192.168.10.1

echo "=== PC-B → LAN-B ==="
sudo ip link add pc-b-eth type veth peer name lan-b-port1
sudo ip link set pc-b-eth netns pc-b
sudo ip link set lan-b-port1 master br-lan-b
sudo ip link set lan-b-port1 up
sudo ip netns exec pc-b ip addr add 192.168.20.10/24 dev pc-b-eth
sudo ip netns exec pc-b ip link set lo up
sudo ip netns exec pc-b ip link set pc-b-eth up
sudo ip netns exec pc-b ip route add default via 192.168.20.1

echo "=== Router 1 ==="
sudo ip link add r1-eth0 type veth peer name wan-port
sudo ip link set r1-eth0 netns r1
sudo ip link set wan-port master br-wan
sudo ip link set wan-port up
sudo ip link add r1-eth2 type veth peer name lan-a-port2
sudo ip link set r1-eth2 netns r1
sudo ip link set lan-a-port2 master br-lan-a
sudo ip link set lan-a-port2 up
sudo ip link add r1-eth1 type veth peer name r2-eth0
sudo ip link set r1-eth1 netns r1
sudo ip link set r2-eth0 netns r2

sudo ip netns exec r1 ip link set lo up
sudo ip netns exec r1 ip link set r1-eth0 up
sudo ip netns exec r1 ip link set r1-eth1 up
sudo ip netns exec r1 ip link set r1-eth2 up
sudo ip netns exec r1 ip addr add 192.168.17.10/24 dev r1-eth0
sudo ip netns exec r1 ip addr add 10.10.12.1/30 dev r1-eth1
sudo ip netns exec r1 ip addr add 192.168.10.1/24 dev r1-eth2
sudo ip netns exec r1 ip route add 192.168.20.0/24 via 10.10.12.2
sudo ip netns exec r1 ip route add default via 192.168.17.1
sudo ip netns exec r1 sysctl -w net.ipv4.ip_forward=1

echo "=== Router 2 ==="
sudo ip link add r2-eth1 type veth peer name lan-b-port2
sudo ip link set r2-eth1 netns r2
sudo ip link set lan-b-port2 master br-lan-b
sudo ip link set lan-b-port2 up

sudo ip netns exec r2 ip link set lo up
sudo ip netns exec r2 ip link set r2-eth0 up
sudo ip netns exec r2 ip link set r2-eth1 up
sudo ip netns exec r2 ip addr add 10.10.12.2/30 dev r2-eth0
sudo ip netns exec r2 ip addr add 192.168.20.1/24 dev r2-eth1
sudo ip netns exec r2 ip route add default via 10.10.12.1
sudo ip netns exec r2 sysctl -w net.ipv4.ip_forward=1

echo "=== Форвардинг на хосте ==="
sudo sysctl -w net.ipv4.ip_forward=1

echo "=== NAT ==="
sudo iptables -t nat -A POSTROUTING -s 192.168.17.0/24 ! -d 192.168.17.0/24 -j MASQUERADE
sudo ip netns exec r1 iptables -t nat -A POSTROUTING -o r1-eth0 -j MASQUERADE
sudo ip netns exec r1 iptables -A FORWARD -i r1-eth0 -o r1-eth1 -j ACCEPT
sudo ip netns exec r1 iptables -A FORWARD -i r1-eth1 -o r1-eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo ip netns exec r1 iptables -A FORWARD -i r1-eth0 -o r1-eth2 -j ACCEPT
sudo ip netns exec r1 iptables -A FORWARD -i r1-eth2 -o r1-eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo ip netns exec r1 iptables -A FORWARD -i r1-eth1 -o r1-eth2 -j ACCEPT
sudo ip netns exec r1 iptables -A FORWARD -i r1-eth2 -o r1-eth1 -j ACCEPT

echo "=== Запуск FRR ==="
sudo mkdir -p /var/run/frr-r1 /var/run/frr-r2
sudo chown frr:frr /var/run/frr-r1 /var/run/frr-r2

sudo ip netns exec r1 /usr/lib/frr/zebra \
  -f /etc/frr-r1/zebra.conf \
  -i /var/run/frr-r1/zebra.pid \
  -z /var/run/frr-r1/zebra.sock \
  -u frr -g frr -N r1 &
sleep 1

sudo ip netns exec r1 /usr/lib/frr/ospfd \
  -f /etc/frr-r1/ospfd.conf \
  -i /var/run/frr-r1/ospfd.pid \
  -z /var/run/frr-r1/zebra.sock \
  -u frr -g frr -N r1 &

sudo ip netns exec r2 /usr/lib/frr/zebra \
  -f /etc/frr-r2/zebra.conf \
  -i /var/run/frr-r2/zebra.pid \
  -z /var/run/frr-r2/zebra.sock \
  -u frr -g frr -N r2 &
sleep 1

sudo ip netns exec r2 /usr/lib/frr/ospfd \
  -f /etc/frr-r2/ospfd.conf \
  -i /var/run/frr-r2/ospfd.pid \
  -z /var/run/frr-r2/zebra.sock \
  -u frr -g frr -N r2 &

echo "=== Готово ==="
echo "Стенд запущен. Проверка:"
sudo ip netns exec pc-a ping -c 2 192.168.10.1
sudo ip netns exec pc-a ping -c 2 192.168.20.10
