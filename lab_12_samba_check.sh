#!/bin/bash
echo "=== Блок 12: Проверка файлового сервера ==="

# Получаем IP Samba-сервера
SAMBA_IP=$(sudo virsh net-dhcp-leases default 2>/dev/null | grep samba | awk '{print $5}' | cut -d/ -f1)
[ -z "$SAMBA_IP" ] && SAMBA_IP="192.168.10.51"

echo "  Samba-сервер IP: $SAMBA_IP"

# Проверка с PC-A
echo "  Доступ с PC-A:"
echo "quit" | sudo ip netns exec pc-a smbclient //$SAMBA_IP/share -N 2>/dev/null && echo "    OK" || echo "    НЕТ"

# Проверка с PC-B
echo "  Доступ с PC-B:"
echo "quit" | sudo ip netns exec pc-b smbclient //$SAMBA_IP/share -N 2>/dev/null && echo "    OK" || echo "    НЕТ"

echo "OK"
