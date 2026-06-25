#!/bin/bash
echo "=== Блок 10: Запуск и настройка Samba-сервера ==="

# Запускаем ВМ, если не запущена
if ! sudo virsh list --name | grep -q samba-server; then
    sudo virsh start samba-server
    echo "  Ожидание загрузки (30 секунд)..."
    sleep 30
fi

# Привязываем интерфейс к мосту (если отвалился)
sudo ip link set vnet69 master br-lan-a 2>/dev/null || true

# Назначаем статический IP внутри ВМ (если потерялся)
sshpass -p "123" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@192.168.10.51 \
  "sudo ip addr add 192.168.10.51/24 dev enp1s0 2>/dev/null; \
   sudo ip route add default via 192.168.10.1 2>/dev/null; \
   sudo systemctl restart smbd 2>/dev/null" 2>/dev/null || true

# Если SSH не работает – пробуем через консоль (однократно)
if ! sshpass -p "123" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 ubuntu@192.168.10.51 "echo OK" 2>/dev/null; then
    echo "  SSH недоступен, настройка через консоль..."
    sudo virsh console samba-server --force <<END
ubuntu
123
sudo ip addr add 192.168.10.51/24 dev enp1s0
sudo ip route add default via 192.168.10.1
sudo systemctl restart smbd
exit
END
fi

echo "  Samba-сервер готов"
echo "OK"
