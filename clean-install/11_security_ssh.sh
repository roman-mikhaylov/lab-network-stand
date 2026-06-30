#!/bin/bash
echo "============================================"
echo " ШАГ 11: SSH-безопасность"
echo "============================================"

sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 <<'EOF'
# Сменить порт SSH на 2222
#sudo sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
#sudo sed -i 's/^Port 22/Port 2222/' /etc/ssh/sshd_config
sudo sed -i '/^Port/d' /etc/ssh/sshd_config
echo "Port 2222" | sudo tee -a /etc/ssh/sshd_config
sudo mkdir -p /run/sshd



# Запретить вход root
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Отключить вход по паролю (только ключи)
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Ограничить пользователей
echo "AllowUsers ubuntu admin1" | sudo tee -a /etc/ssh/sshd_config

# Перезапустить SSH
sudo systemctl restart sshd

# Открыть порт 2222 в ufw
sudo ufw allow 2222/tcp
sudo ufw delete allow 22/tcp 2>/dev/null

echo "SSH-OK"
EOF

echo ""
echo "РЕЗУЛЬТАТ:"
echo "  SSH порт: 2222 (22 закрыт)"
echo "  Root login: запрещён"
echo "  Парольный вход: отключён"
echo "  Разрешены: ubuntu, admin1"
echo "  Файрвол: порт 2222 открыт, 22 закрыт"
echo "OK"
