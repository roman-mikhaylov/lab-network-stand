#!/bin/bash
echo "=== Блок 11: Резервное копирование виртуальных машин ==="
BACKUP_DIR="$HOME/vm-backup"
mkdir -p "$BACKUP_DIR"

# Список ВМ для бэкапа
VMS=("kvm-router" "samba-server")

for VM in "${VMS[@]}"; do
    echo "  Обработка $VM..."

    # Проверяем, запущена ли ВМ – если да, выключаем для консистентности
    if sudo virsh list --name | grep -q "^$VM$"; then
        echo "    Остановка $VM..."
        sudo virsh shutdown "$VM" 2>/dev/null || true
        sleep 10
        # Принудительное выключение, если не остановилась
        if sudo virsh list --name | grep -q "^$VM$"; then
            sudo virsh destroy "$VM" 2>/dev/null || true
        fi
    fi

    # Сохраняем XML-конфигурацию
    echo "    Сохранение XML-конфигурации..."
    sudo virsh dumpxml "$VM" > "$BACKUP_DIR/${VM}.xml"

    # Копируем диск(и) ВМ
    echo "    Копирование дисков..."
    DISKS=$(sudo virsh domblklist "$VM" | awk '$1 ~ /vda|vdb/ {print $2}')
    for DISK in $DISKS; do
        BASENAME=$(basename "$DISK")
        echo "      Копирование $DISK -> $BACKUP_DIR/${VM}_${BASENAME}"
        sudo cp "$DISK" "$BACKUP_DIR/${VM}_${BASENAME}"
    done

    # Запускаем ВМ обратно, если она была запущена
    if ! sudo virsh list --name | grep -q "^$VM$"; then
        echo "    Запуск $VM..."
        sudo virsh start "$VM" 2>/dev/null || true
    fi
    echo ""
done

echo "  Резервное копирование завершено."
echo "  Файлы находятся в: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"
echo "OK"
