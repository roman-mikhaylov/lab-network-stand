## Шпаргалка: решение типовых проблем на стенде

---

### 1. DNS не работает (не резолвятся доменные имена)

**Симптомы:** `Temporary failure resolving`, `Could not resolve host`

**Решение:**
```bash
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

**Где применять:** внутри любой ВМ (kvm-router, org-server, samba-server), внутри netns (pc-a, pc-b, r2).

---

### 2. DHCP-IP конфликтует со статическим IP

**Симптомы:** два IP на интерфейсе (`192.168.10.10` и `192.168.10.5x`), интернета нет

**Решение:**
```bash
sudo ip addr del 192.168.10.XX/24 dev enp1s0
sudo ip route del default via 192.168.10.1 proto dhcp 2>/dev/null
```

**Где:** org-server, samba-server (любая ВМ со статическим IP).

**Навсегда:** удалить пакет `isc-dhcp-client` или прописать `dhcp4: false` в netplan.

---

### 3. Интернета нет ни у кого (даже у KVM‑роутера)

**Симптомы:** `ping 8.8.8.8` не идёт с KVM‑роутера

**Решение — проверить NAT на хосте:**
```bash
sudo iptables -t nat -L POSTROUTING -v | grep MASQUERADE
```
Если правила нет — добавить:
```bash
sudo iptables -t nat -A POSTROUTING -s 192.168.17.0/24 ! -d 192.168.17.0/24 -j MASQUERADE
```

---

### 4. Интернет есть у KVM‑роутера, но нет у других ВМ

**Симптомы:** KVM‑роутер пингует 8.8.8.8, org-server — нет

**Решение — добавить NAT и FORWARD на KVM‑роутере:**
```bash
sudo iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -o enp1s0 -j MASQUERADE
sudo iptables -A FORWARD -i enp3s0 -o enp1s0 -j ACCEPT
sudo iptables -A FORWARD -i enp1s0 -o enp3s0 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

---

### 5. ВМ недоступна по сети (пинг не идёт)

**Симптомы:** ВМ запущена, но `ping 192.168.10.10` не идёт

**Проверить:**
1. Интерфейс ВМ в мосту:
```bash
sudo virsh domiflist <имя_ВМ>
bridge link show br-lan-a | grep vnet
```
2. IP внутри ВМ:
```bash
sudo virsh console <имя_ВМ>
ip addr show enp1s0 | grep inet
```
3. Если IP нет — назначить:
```bash
sudo ip addr add 192.168.10.10/24 dev enp1s0
sudo ip link set enp1s0 up
sudo ip route add default via 192.168.10.1
```

---

### 6. SSH не подключается (Connection refused / Permission denied)

**Симптомы:** `ssh: connect to host ... port 22: Connection refused`

**Решение:**
1. Удалить старый ключ хоста:
```bash
ssh-keygen -f "/home/egor/.ssh/known_hosts" -R "IP_адрес"
```
2. Подключиться заново:
```bash
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@IP_адрес
```

---

### 7. OSPF-соседства нет (маршруты не передаются)

**Симптомы:** `show ip ospf neighbor` пусто

**Решение — перезапустить FRR и добавить сети:**
```bash
sudo systemctl restart frr
sudo vtysh -c "conf t" -c "router ospf" -c "router-id X.X.X.X" -c "network 10.10.12.0/30 area 0" -c "network 192.168.X.0/24 area 0"
```

---

### 8. DHCP не выдаёт адреса (PC‑A или PC‑B без IP)

**Симптомы:** `ip addr show pc-a-eth` показывает только IPv6

**Решение — перезапустить DHCP:**
```bash
# На Router2 (netns r2):
sudo ip netns exec r2 dhcpd -4 -cf /etc/dhcp/dhcpd.conf -lf /var/lib/dhcp/dhcpd.leases -f r2-eth1 &>/dev/null &

# На KVM-роутере (для LAN-A):
sudo systemctl restart isc-dhcp-server

# Запросить IP клиенту:
sudo ip netns exec pc-a dhclient pc-a-eth
```

---

### 9. Блокировка apt (Could not get lock)

**Симптомы:** `E: Could not get lock /var/lib/apt/lists/lock`

**Решение:**
```bash
sudo kill -9 $(sudo lsof /var/lib/apt/lists/lock | tail -1 | awk '{print $2}')
sudo rm -f /var/lib/apt/lists/lock
sudo rm -f /var/lib/dpkg/lock-frontend
```

---

### 10. Сеть отвалилась после перезагрузки

**Решение — запустить цепочку скриптов:**
```bash
cd ~/lab-network-stand/clean-install
./00_cleanup.sh && ./01_bridges.sh && ./02_netns.sh && ./03_clients.sh && ./04_router2.sh && ./05_kvm_router.sh && ./06_kvm_setup.sh && ./07_dhcp_clients.sh && ./08_wait_check.sh
```

---

### 11. Проброс порта не работает (Samba/сайт недоступны из WAN)

**Решение — добавить DNAT на KVM‑роутере:**
```bash
# Проброс порта 80 (сайт):
sudo iptables -t nat -A PREROUTING -i enp1s0 -p tcp --dport 80 -j DNAT --to-destination 192.168.10.10:80
sudo iptables -A FORWARD -i enp1s0 -o enp3s0 -p tcp --dport 80 -d 192.168.10.10 -j ACCEPT

# Проброс порта 445 (Samba):
sudo iptables -t nat -A PREROUTING -i enp1s0 -p tcp --dport 445 -j DNAT --to-destination 192.168.10.10:445
sudo iptables -A FORWARD -i enp1s0 -o enp3s0 -p tcp --dport 445 -d 192.168.10.10 -j ACCEPT
```

---

## Таблица: какой IP где искать

| Устройство | IP	     | Как подключиться |
|------------|---------------|-----------------|
| KVM‑роутер | 192.168.17.10 | `ssh ubuntu@192.168.17.10` |
| Router2 (netns) | 10.10.12.2 | `sudo ip netns exec r2 bash` |
| PC‑A | DHCP (192.168.10.50+) | `sudo ip netns exec pc-a bash` |
| PC‑B | DHCP (192.168.20.50+) | `sudo ip netns exec pc-b bash` |
| Org‑server | 192.168.10.10 | `ssh ubuntu@192.168.10.10` |
| Samba‑сервер | 192.168.10.51 | `ssh ubuntu@192.168.10.51` |

---

---

## 12. SSH упал после изменения конфига

**Симптомы:** `ssh.service failed`, `Badly formatted port number`

**Причина:** задвоилась строка `Port` в `/etc/ssh/sshd_config`.

**Решение:**
```bash
# Проверить конфиг
sudo sshd -t

# Удалить все строки Port
sudo sed -i '/^Port/d' /etc/ssh/sshd_config

# Добавить одну правильную
echo "Port 2222" | sudo tee -a /etc/ssh/sshd_config

# Применить
sudo sshd -t && sudo systemctl restart sshd
