#!/bin/bash
echo "=== Блок 10: Запуск и настройка Samba-сервера ==="

# Запускаем ВМ, если не запущена
if ! sudo virsh list --name | grep -q samba-server; then
    sudo virsh start samba-server
    echo "  Ожидание загрузки (30 секунд)..."
    sleep 30
fi

# Подключаем интерфейс к мосту
VNET=$(sudo virsh domiflist samba-server | awk '/bridge/{print $1}')
if [ -n "$VNET" ]; then
    sudo ip link set "$VNET" master br-lan-a 2>/dev/null || true
fi

# Назначаем IP и маршрут внутри ВМ
sudo virsh console samba-server --force <<'CMDS' 2>/dev/null
ubuntu
123
sudo ip addr add 192.168.10.51/24 dev enp1s0 2>/dev/null
sudo ip route add default via 192.168.10.1 2>/dev/null
sudo systemctl restart smbd 2>/dev/null
exit
CMDS

echo "  Samba-сервер готов"
echo "OK"
