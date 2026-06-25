#!/bin/bash
echo "=== Блок 6: KVM-роутер ==="
if ! sudo virsh list --name | grep -q kvm-router; then
    sudo virsh start kvm-router
    echo "Ожидание загрузки (60 секунд)..."
    sleep 60
fi
echo "OK"
