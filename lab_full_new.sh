#!/bin/bash
set -e

echo "============================================"
echo "  Запуск учебного сетевого стенда"
echo "============================================"

# 1. Очистка старых veth-пар (на всякий случай)
echo ">>> Очистка старых интерфейсов..."
sudo ip link del pc-a-eth 2>/dev/null || true
sudo ip link del pc-b-eth 2>/dev/null || true
sudo ip link del r2-eth0 2>/dev/null || true
sudo ip link del r2-eth1 2>/dev/null || true
sudo ip link del lan-a-port1 2>/dev/null || true
sudo ip link del lan-a-port2 2>/dev/null || true
sudo ip link del lan-b-port1 2>/dev/null || true
sudo ip link del lan-b-port2 2>/dev/null || true
sudo ip link del transit-r2 2>/dev/null || true

# 2. Создание мостов
echo ">>> Создание bridge..."
sudo ip link add br-lan-a type bridge 2>/dev/null || true
sudo ip link add br-lan-b type bridge 2>/dev/null || true
sudo ip link add br-wan type bridge 2>/dev/null || true
sudo ip link add br-transit type bridge 2>/dev/null || true
sudo ip link set br-lan-a up
sudo ip link set br-lan-b up
sudo ip link set br-wan up
sudo ip link set br-transit up
sudo ip addr add 192.168.17.1/24 dev br-wan 2>/dev/null || true

# 3. Создание netns
echo ">>> Создание network namespaces..."
sudo ip netns add pc-a 2>/dev/null || true
sudo ip netns add pc-b 2>/dev/null || true
sudo ip netns add r2 2>/dev/null || true

# 4. DNS для всех netns
echo ">>> Настройка DNS..."
sudo mkdir -p /etc/netns/pc-a /etc/netns/pc-b /etc/netns/r2
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/pc-a/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/pc-b/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/r2/resolv.conf

# 5. Подключение PC-A к LAN-A
echo ">>> Настройка PC-A..."
sudo ip link add pc-a-eth type veth peer name lan-a-port1
sudo ip link set pc-a-eth netns pc-a
sudo ip link set lan-a-port1 master br-lan-a
sudo ip link set lan-a-port1 up
sudo ip netns exec pc-a ip link set lo up
sudo ip netns exec pc-a ip link set pc-a-eth up

# 6. Подключение PC-B к LAN-B
echo ">>> Настройка PC-B..."
sudo ip link add pc-b-eth type veth peer name lan-b-port1
sudo ip link set pc-b-eth netns pc-b
sudo ip link set lan-b-port1 master br-lan-b
sudo ip link set lan-b-port1 up
sudo ip netns exec pc-b ip link set lo up
sudo ip netns exec pc-b ip link set pc-b-eth up

# 7. Настройка Router2
echo ">>> Настройка Router2..."
sudo ip link add r2-eth1 type veth peer name lan-b-port2
sudo ip link set r2-eth1 netns r2
sudo ip link set lan-b-port2 master br-lan-b
sudo ip link set lan-b-port2 up

sudo ip link add r2-eth0 type veth peer name transit-r2
sudo ip link set r2-eth0 netns r2
sudo ip link set transit-r2 master br-transit
sudo ip link set transit-r2 up

sudo ip netns exec r2 ip link set lo up
sudo ip netns exec r2 ip link set r2-eth1 up
sudo ip netns exec r2 ip link set r2-eth0 up
sudo ip netns exec r2 ip addr add 192.168.20.1/24 dev r2-eth1 2>/dev/null || true
sudo ip netns exec r2 ip addr add 10.10.12.2/30 dev r2-eth0 2>/dev/null || true
sudo ip netns exec r2 ip route add default via 10.10.12.1 2>/dev/null || true

# 8. FRR на Router2
echo ">>> Запуск FRR на Router2..."
sudo pkill -f "zebra.*frr-r2" 2>/dev/null || true
sudo pkill -f "ospfd.*frr-r2" 2>/dev/null || true
sudo mkdir -p /var/run/frr-r2
sudo chown frr:frr /var/run/frr-r2
sleep 1
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

# 9. Запуск KVM-роутера
echo ">>> Запуск KVM-роутера..."
if ! sudo virsh list --name | grep -q kvm-router; then
    sudo virsh start kvm-router
    echo "  Ожидание загрузки KVM-роутера (60 секунд)..."
    sleep 60
fi

# 10. Настройка KVM-роутера (интерфейсы, NAT, форвардинг, файрвол)
echo ">>> Настройка KVM-роутера..."
# Ждём, пока ВМ станет доступна
for i in {1..10}; do
    ping -c 1 192.168.17.10 &>/dev/null && break
    echo "  Ожидание доступности KVM-роутера..."
    sleep 5
done

# Функция для выполнения команд внутри ВМ через SSH с паролем
run_in_vm() {
    sshpass -p "123" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@192.168.17.10 "$1" 2>/dev/null
}

# Проверим, есть ли sshpass, если нет — установим
if ! command -v sshpass &>/dev/null; then
    sudo apt install -y sshpass 2>/dev/null || true
fi

# Убедимся, что внутри ВМ включён вход по паролю
# (это нужно сделать один раз вручную, если ещё не сделано)

echo "  Настройка интерфейсов и форвардинга в KVM-роутере..."
run_in_vm "sudo ip addr add 192.168.17.10/24 dev enp1s0 2>/dev/null"
run_in_vm "sudo ip addr add 10.10.12.1/30 dev enp2s0 2>/dev/null"
run_in_vm "sudo ip addr add 192.168.10.1/24 dev enp3s0 2>/dev/null"
run_in_vm "sudo ip link set enp2s0 up"
run_in_vm "sudo ip link set enp3s0 up"
run_in_vm "sudo ip route add default via 192.168.17.1 2>/dev/null"
run_in_vm "sudo sysctl -w net.ipv4.ip_forward=1"

echo "  Настройка NAT и файрвола в KVM-роутере..."
run_in_vm "sudo iptables -t nat -A POSTROUTING -o enp1s0 -j MASQUERADE"
run_in_vm "sudo iptables -F FORWARD"
run_in_vm "sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT"
run_in_vm "sudo iptables -A FORWARD -s 192.168.10.0/24 -d 192.168.20.0/24 -j ACCEPT"
run_in_vm "sudo iptables -A FORWARD -s 192.168.20.0/24 -d 192.168.10.0/24 -j ACCEPT"
run_in_vm "sudo iptables -A FORWARD -i enp3s0 -o enp1s0 -j ACCEPT"
run_in_vm "sudo iptables -A FORWARD -i enp2s0 -o enp1s0 -j ACCEPT"
run_in_vm "sudo iptables -A FORWARD -i lo -j ACCEPT"
run_in_vm "sudo iptables -P FORWARD DROP"
run_in_vm "sudo iptables -A INPUT -s 192.168.10.0/24 -d 192.168.10.1 -p tcp --dport 22 -j DROP"

echo "  Запуск DHCP на KVM-роутере..."
run_in_vm "sudo systemctl restart isc-dhcp-server"

# 11. DHCP на Router2
echo ">>> Запуск DHCP на Router2..."
sudo pkill -f "dhcpd.*r2-eth1" 2>/dev/null || true
sudo ip netns exec r2 dhcpd -4 -f -d r2-eth1 &>/dev/null &
sleep 2

# 12. Получение адресов по DHCP для PC-A и PC-B
echo ">>> Получение DHCP для PC-A и PC-B..."
sudo pkill -f "dhclient.*pc-a-eth" 2>/dev/null || true
sudo pkill -f "dhclient.*pc-b-eth" 2>/dev/null || true
sudo ip netns exec pc-a dhclient -v pc-a-eth 2>/dev/null &
sudo ip netns exec pc-b dhclient -v pc-b-eth 2>/dev/null &
sleep 5

# 13. Добавление маршрутов
echo ">>> Добавление маршрутов..."
sudo ip netns exec pc-a ip route add default via 192.168.10.1 2>/dev/null || true
sudo ip netns exec pc-a ip route add 192.168.20.0/24 via 192.168.10.1 2>/dev/null || true
sudo ip netns exec pc-b ip route add default via 192.168.20.1 2>/dev/null || true
sudo ip netns exec pc-b ip route add 192.168.10.0/24 via 192.168.20.1 2>/dev/null || true

echo ""
echo "============================================"
echo "  Стенд запущен!"
echo "============================================"
echo ""
echo "Проверка связи:"
echo "  PC-A -> PC-B:"
sudo ip netns exec pc-a ping -c 2 192.168.20.50 && echo "  OK" || echo "  (не работает)"
echo "  PC-A -> интернет:"
sudo ip netns exec pc-a ping -c 2 8.8.8.8 && echo "  OK" || echo "  (не работает)"
echo ""
echo "Консоль KVM-роутера:  sudo virsh console kvm-router"
echo "Консоль Router2:      sudo ip netns exec r2 bash"
echo "Консоль PC-A:         sudo ip netns exec pc-a bash"
echo "Консоль PC-B:         sudo ip netns exec pc-b bash"
