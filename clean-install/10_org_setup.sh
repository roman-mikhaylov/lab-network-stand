#!/bin/bash
echo "============================================"
echo " ШАГ 10: Настройка Org-server"
echo "============================================"

# Ждём доступности
echo "  Ожидание доступности org-server..."
for i in {1..10}; do
    if ping -c 1 -W 2 192.168.10.10 >/dev/null 2>&1; then
        echo "  org-server доступен"
        break
    fi
    echo "  Ожидание ($i/10)..."
    sleep 5
done

# Установка пакетов
echo "  Установка пакетов..."

sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 "echo nameserver 8.8.8.8 | sudo tee /etc/resolv.conf; sudo apt update && sudo apt install -y samba nginx git mariadb-server" 2>/dev/null

# Пользователи и Samba
echo "  Настройка пользователей и Samba..."
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 <<'EOF'
sudo groupadd staff 2>/dev/null
sudo useradd -m -s /bin/bash -G staff admin1 2>/dev/null
sudo useradd -m -s /bin/bash user1 2>/dev/null
sudo useradd -m -s /bin/bash user2 2>/dev/null
sudo usermod -aG sudo admin1
sudo usermod -aG staff user1
sudo usermod -aG staff user2
echo "admin1:admin123" | sudo chpasswd
echo "user1:user123" | sudo chpasswd
echo "user2:user123" | sudo chpasswd

sudo mkdir -p /srv/samba/public /srv/samba/private /srv/samba/shared
sudo chmod 777 /srv/samba/public
sudo chown root:staff /srv/samba/private && sudo chmod 770 /srv/samba/private
sudo chown root:staff /srv/samba/shared && sudo chmod 770 /srv/samba/shared

for user in admin1 user1 user2; do
    sudo mkdir -p /srv/samba/$user
    sudo chmod 700 /srv/samba/$user
    sudo chown $user:$user /srv/samba/$user
done

sudo tee -a /etc/samba/smb.conf <<'SMB'

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

[shared]
  path = /srv/samba/shared
  browseable = yes
  read only = no
  valid users = @staff

[homes]
  comment = Home Directories
  browseable = no
  read only = no
  valid users = %S
SMB
echo -e "admin123\nadmin123" | sudo smbpasswd -a admin1 2>/dev/null
echo -e "user123\nuser123" | sudo smbpasswd -a user1 2>/dev/null
echo -e "user123\nuser123" | sudo smbpasswd -a user2 2>/dev/null
sudo systemctl restart smbd
EOF

# Клонирование сайта
echo "  Клонирование сайта..."
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 "cd /var/www/html && sudo rm -rf * && sudo git clone https://github.com/roman-mikhaylov/dostaffkin.git . && sudo cp -r docs/* . 2>/dev/null; sudo chown -R www-data:www-data /var/www/html" 2>/dev/null

# MariaDB
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 <<'MARIADB'
sudo mysql <<'SQL'
CREATE DATABASE IF NOT EXISTS dostaffkin;
CREATE USER IF NOT EXISTS 'dostaffkin'@'localhost' IDENTIFIED BY 'dbpass123';
GRANT ALL PRIVILEGES ON dostaffkin.* TO 'dostaffkin'@'localhost';
FLUSH PRIVILEGES;
SQL
MARIADB

# Админ-раздел с Basic Auth
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 <<'ADMIN'
sudo apt install -y apache2-utils 2>/dev/null
sudo htpasswd -cb /etc/nginx/.htpasswd admin admin123 2>/dev/null
sudo mkdir -p /var/www/html/admin
echo '<h1>Admin Panel</h1><p>Welcome, admin!</p>' | sudo tee /var/www/html/admin/index.html
sudo chown -R www-data:www-data /var/www/html/admin
sudo tee /etc/nginx/sites-available/default <<'NGINX'
server {
    listen 80;
    server_name _;
    root /var/www/html;
    index index.html;

    location /admin {
        auth_basic "Admin Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
        alias /var/www/html/admin/;
        try_files $uri $uri/ /admin/index.html;
    }

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX
sudo systemctl restart nginx
ADMIN




# Бэкапы
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 <<'BACKUP'
sudo mkdir -p /backup
sudo tee /usr/local/bin/backup.sh <<'SCRIPT'
#!/bin/bash
DATE=$(date +%Y%m%d)
mkdir -p /backup/$DATE
tar czf /backup/$DATE/etc.tgz /etc 2>/dev/null
tar czf /backup/$DATE/srv.tgz /srv 2>/dev/null
tar czf /backup/$DATE/www.tgz /var/www 2>/dev/null
find /backup -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null
echo "Backup done: $DATE"
SCRIPT
sudo chmod +x /usr/local/bin/backup.sh
echo "0 2 * * * /usr/local/bin/backup.sh" | sudo crontab -
BACKUP

# Диагностика
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 <<'CHECK'
sudo tee /usr/local/bin/check-services.sh <<'SCRIPT'
#!/bin/bash
echo "=== Диагностика org-server ==="
echo "Дата: $(date)"
echo "Сетевые интерфейсы:"; ip addr show enp1s0 | grep inet
echo "Службы:"
systemctl status nginx | grep Active | awk '{print "  Nginx: " $2}'
systemctl status smbd | grep Active | awk '{print "  Samba: " $2}'
systemctl status sshd | grep Active | awk '{print "  SSH: " $2}'
systemctl status mariadb | grep Active | awk '{print "  MariaDB: " $2}'
echo "Дисковое пространство:"; df -h / | tail -1
echo "Последний бэкап:"; ls -lt /backup/ | head -2
echo "Пользователи:"; grep -E "admin1|user1|user2" /etc/passwd | cut -d: -f1
echo "Открытые порты:"; sudo ss -tlnp | grep -E "22|80|445|3306"
echo "=== Диагностика завершена ==="
SCRIPT
sudo chmod +x /usr/local/bin/check-services.sh
CHECK

# Правило для Samba на KVM-роутере
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.17.10 "sudo iptables -A FORWARD -p tcp --dport 445 -d 192.168.10.10 -j ACCEPT" 2>/dev/null

# Файрвол на org-server
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 "sudo ufw allow 22/tcp; sudo ufw allow 80/tcp; sudo ufw allow 445/tcp; sudo ufw --force enable" 2>/dev/null

echo ""
echo "РЕЗУЛЬТАТ:"
echo "  Пользователи: admin1 (sudo), user1, user2"
echo "  Samba: public, private, shared, личные папки"
echo "  Nginx + сайт Dostaffkin"
echo "  MariaDB + база dostaffkin"
echo "  Файрвол: открыты 22, 80, 445"
echo "  Бэкап: ежедневно в 2:00 в /backup"
echo "  Диагностика: /usr/local/bin/check-services.sh"
echo ""
echo "  Проверка:"
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 "systemctl status smbd | grep Active | awk '{print \"    Samba: \" \$2}'"
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 "systemctl status nginx | grep Active | awk '{print \"    Nginx: \" \$2}'"
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 "systemctl status mariadb | grep Active | awk '{print \"    MariaDB: \" \$2}'"
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 "curl -s http://localhost | head -1 | grep -q html && echo '    Сайт: OK' || echo '    Сайт: ОШИБКА'"
echo "OK"
