#!/bin/bash
echo "=== Блок 12: Восстановление виртуальной машины из резервной копии ==="
BACKUP_DIR="$HOME/vm-backup"

if [ -z "$1" ]; then
    echo "Укажите имя ВМ для восстановления: kvm-router или samba-server"
    exit 1
fi

VM="$1"
XML_FILE="$BACKUP_DIR/${VM}.xml"
DISK_BACKUP=$(ls "$BACKUP_DIR/${VM}_"*.qcow2 2>/dev/null | head -1)

if [ ! -f "$XML_FILE" ] || [ -z "$DISK_BACKUP" ]; then
    echo "Резервная копия для $VM не найдена в $BACKUP_DIR"
    exit 1
fi

echo "  Восстановление $VM из резервной копии..."

# Остановка и удаление существующей ВМ
if sudo virsh list --name | grep -q "^$VM$"; then
    sudo virsh destroy "$VM" 2>/dev/null || true
fi
sudo virsh undefine "$VM" --remove-all-storage 2>/dev/null || true

# Копируем диск обратно в стандартное хранилище
TARGET_DISK="/var/lib/libvirt/images/$(basename "$DISK_BACKUP" | sed "s/${VM}_//")"
echo "  Копирование диска в $TARGET_DISK..."
sudo cp "$DISK_BACKUP" "$TARGET_DISK"
sudo chown libvirt-qemu:libvirt-qemu "$TARGET_DISK"

# Создаём ВМ из сохранённой XML-конфигурации
echo "  Создание ВМ из XML..."
sudo virsh define "$XML_FILE"

# Запускаем ВМ
echo "  Запуск $VM..."
sudo virsh start "$VM"

echo "  Восстановление завершено."
echo "OK"
