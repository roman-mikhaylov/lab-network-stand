#!/bin/bash
echo "============================================"
echo " ШАГ 04: Настройка Router2 (OSPF + DHCP)"
echo "============================================"

# veth к LAN-B
sudo ip link add r2-eth1 type veth peer name lan-b-port2
sudo ip link set r2-eth1 netns r2
sudo ip link set lan-b-port2 master br-lan-b
sudo ip link set lan-b-port2 up

# veth к Transit
sudo ip link add r2-eth0 type veth peer name transit-r2
sudo ip link set r2-eth0 netns r2
sudo ip link set transit-r2 master br-transit
sudo ip link set transit-r2 up

# Настройка интерфейсов внутри r2
sudo ip netns exec r2 ip link set lo up
sudo ip netns exec r2 ip link set r2-eth1 up
sudo ip netns exec r2 ip link set r2-eth0 up
sudo ip netns exec r2 ip addr add 192.168.20.1/24 dev r2-eth1
sudo ip netns exec r2 ip addr add 10.10.12.2/30 dev r2-eth0
sudo ip netns exec r2 ip route add default via 10.10.12.1

# FRR
sudo mkdir -p /var/run/frr-r2 /etc/frr-r2
sudo chown frr:frr /var/run/frr-r2 2>/dev/null || true

cat > /tmp/r2-zebra.conf <<'FRR'
hostname r2
interface r2-eth0
 ip address 10.10.12.2/30
interface r2-eth1
 ip address 192.168.20.1/24
line vty
 no login
FRR

cat > /tmp/r2-ospfd.conf <<'FRR'
hostname r2
router ospf
 router-id 10.10.12.2
 network 10.10.12.0/30 area 0
 network 192.168.20.0/24 area 0
line vty
 no login
FRR

sudo pkill -f "zebra.*frr-r2" 2>/dev/null || true
sudo pkill -f "ospfd.*frr-r2" 2>/dev/null || true
sleep 1

sudo ip netns exec r2 /usr/lib/frr/zebra -f /tmp/r2-zebra.conf -i /var/run/frr-r2/zebra.pid -z /var/run/frr-r2/zebra.sock -u frr -g frr -N r2 &
sleep 1
sudo ip netns exec r2 /usr/lib/frr/ospfd -f /tmp/r2-ospfd.conf -i /var/run/frr-r2/ospfd.pid -z /var/run/frr-r2/zebra.sock -u frr -g frr -N r2 &

# DHCP
sudo ip netns exec r2 mkdir -p /var/lib/dhcp
sudo ip netns exec r2 touch /var/lib/dhcp/dhcpd.leases
sudo ip netns exec r2 chmod 777 /var/lib/dhcp/dhcpd.leases
sudo ip netns exec r2 tee /etc/dhcp/dhcpd.conf <<'DHCP' >/dev/null
default-lease-time 600;
max-lease-time 7200;
option subnet-mask 255.255.255.0;
option broadcast-address 192.168.20.255;
option routers 192.168.20.1;
option domain-name-servers 8.8.8.8, 8.8.4.4;
subnet 192.168.20.0 netmask 255.255.255.0 {
  range 192.168.20.50 192.168.20.100;
}
DHCP
sudo ip netns exec r2 dhcpd -4 -cf /etc/dhcp/dhcpd.conf -lf /var/lib/dhcp/dhcpd.leases -f r2-eth1 &>/dev/null &
sleep 3
# Проверка и перезапуск DHCP, если не работает
if ! sudo ip netns exec r2 ps aux | grep -q "[d]hcpd"; then
    echo "  DHCP не запустился, пробуем ещё раз..."
    sudo ip netns exec r2 dhcpd -4 -cf /etc/dhcp/dhcpd.conf -lf /var/lib/dhcp/dhcpd.leases -f r2-eth1 &>/dev/null &
    sleep 3
fi



echo ""
echo "РЕЗУЛЬТАТ:"
echo "  Router2 настроен:"
echo "    r2-eth0: 10.10.12.2/30 (Transit → KVM-роутер)"
echo "    r2-eth1: 192.168.20.1/24 (LAN-B, шлюз для PC-B)"
echo "  OSPF: процесс запущен, router-id 10.10.12.2"
echo "  DHCP: пул 192.168.20.50-100, шлюз 192.168.20.1"
echo ""
echo "  Проверка:"
sudo ip netns exec r2 ip addr show r2-eth0 | grep -q 10.10.12.2 && echo "    IP r2-eth0: OK" || echo "    IP r2-eth0: ОШИБКА"
sudo ip netns exec r2 ip addr show r2-eth1 | grep -q 192.168.20.1 && echo "    IP r2-eth1: OK" || echo "    IP r2-eth1: ОШИБКА"
sudo ip netns exec r2 ps aux | grep -q "[d]hcpd" && echo "    DHCP: OK" || echo "    DHCP: ОШИБКА"
echo "OK"
