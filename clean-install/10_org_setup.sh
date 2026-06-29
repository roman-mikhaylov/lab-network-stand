#!/bin/bash
echo "============================================"
echo " ШАГ 10: Настройка Org-server"
echo "============================================"

SSH="sshpass -p 123 ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10"

echo "  Установка обновлений и пакетов..."
$SSH "echo nameserver 8.8.8.8 | sudo tee /etc/resolv.conf; sudo apt update && sudo apt install -y samba nginx git" 2>/dev/null

echo "  Создание пользователей и групп..."
$SSH "sudo groupadd staff 2>/dev/null; sudo useradd -m -s /bin/bash -G staff admin1 2>/dev/null; sudo useradd -m -s /bin/bash user1 2>/dev/null; sudo useradd -m -s /bin/bash user2 2>/dev/null; sudo usermod -aG sudo admin1; echo admin1:admin123 | sudo chpasswd; echo user1:user123 | sudo chpasswd; echo user2:user123 | sudo chpasswd"

echo "  Настройка Samba..."
$SSH "sudo mkdir -p /srv/samba/public /srv/samba/private; sudo chmod 777 /srv/samba/public; sudo chown root:staff /srv/samba/private; sudo chmod 770 /srv/samba/private"
$SSH "sudo tee -a /etc/samba/smb.conf <<'EOF'

[public]
  path = /srv/samba/public
  browseable = yes
  read only = no
  guest ok = yes

[private]
  path = /srv/samba/private
  browseable = yes
  read only = no
  valid users = @staff
EOF"
$SSH "echo -e 'admin123\nadmin123' | sudo smbpasswd -a admin1 2>/dev/null; echo -e 'user123\nuser123' | sudo smbpasswd -a user1 2>/dev/null; echo -e 'user123\nuser123' | sudo smbpasswd -a user2 2>/dev/null"
$SSH "sudo systemctl restart smbd"

echo "  Настройка Nginx + сайт..."
$SSH "cd /var/www/html && sudo rm -rf * && sudo git clone https://github.com/roman-mikhaylov/dostaffkin.git . 2>/dev/null"
$SSH "sudo chown -R www-data:www-data /var/www/html"

echo "  Настройка файрвола (ufw)..."
$SSH "sudo ufw allow 22/tcp; sudo ufw allow 80/tcp; sudo ufw allow 445/tcp; sudo ufw --force enable"

echo "  Настройка cron (ежедневный бэкап)..."
$SSH "echo '0 2 * * * tar czf /backup/etc-\$(date +\\%Y\\%m\\%d).tgz /etc 2>/dev/null; tar czf /backup/srv-\$(date +\\%Y\\%m\\%d).tgz /srv 2>/dev/null' | sudo crontab -"

echo ""
# Правило для Samba на KVM-роутере
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.17.10 "sudo iptables -A FORWARD -p tcp --dport 445 -d 192.168.10.10 -j ACCEPT" 2>/dev/null

echo "РЕЗУЛЬТАТ:"
echo "  Пользователи: admin1 (sudo, staff), user1, user2"
echo "  Samba: public (всем), private (staff)"
echo "  Nginx: сайт Dostaffkin на порту 80"
echo "  Файрвол: открыты 22, 80, 445"
echo "  Бэкап: ежедневно в 2:00 в /backup"
echo ""
echo "  Проверка:"
$SSH "systemctl status smbd | grep Active | awk '{print \"    Samba: \" \$2}'"
$SSH "systemctl status nginx | grep Active | awk '{print \"    Nginx: \" \$2}'"
$SSH "sudo ufw status | grep Status"
$SSH "curl -s http://localhost | head -1 | grep -q html && echo '    Сайт: OK' || echo '    Сайт: ОШИБКА'"
echo "OK"
