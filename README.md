# Учебный гибридный сетевой стенд

## Версия
v1.0 — стабильная (2026-06-26)

## Описание
Стенд для изучения сетевых технологий: OSPF, DHCP, файловый сервер Samba, межсетевой экран, проброс портов.
Сочетает аппаратную виртуализацию (KVM) и сетевые пространства имён (network namespaces).

## Архитектура
WAN (192.168.17.0/24) — br-wan
│
KVM-роутер (Ubuntu VM) 192.168.17.10
│-- enp2s0: 10.10.12.1/30 (Transit)
│-- enp3s0: 192.168.10.1/24 (LAN-A)
│
├── LAN-A (br-lan-a)
│ ├── PC-A (netns, DHCP)
│ └── Samba-сервер (VM, 192.168.10.51)
│
├── Transit (br-transit)
│ └── Router2 (netns, 10.10.12.2)
│
└── LAN-B (br-lan-b)



## Быстрый запуск (после перезагрузки)
```bash
cd ~/lab-network-stand
sudo ./lab_01_cleanup.sh && \
sudo ./lab_02_bridges.sh && \
sudo ./lab_03_netns.sh && \
sudo ./lab_04_clients.sh && \
sudo ./lab_05_router2.sh && \
sudo ./lab_06_kvm_router.sh && \
sudo ./lab_07_dhcp_clients.sh && \
./lab_08_check.sh && \
sudo ./lab_10_samba_start.sh && \
./lab_09_firewall.sh

## Компоненты

| Компонент | Технология | Функции |
|-----------|-----------|---------|
| KVM-роутер | KVM (Ubuntu VM) | OSPF, NAT, DHCP LAN-A, файрвол, проброс портов |
| Router2 | Network namespace | OSPF, DHCP LAN-B |
| PC-A, PC-B | Network namespaces | Клиенты, DHCP |
| Samba-сервер | KVM (Ubuntu VM) | Файловый сервер (гостевой доступ) |
| Файрвол | iptables на KVM-роутере | DROP по умолчанию, разрешён межсетевой трафик и интернет |
| Проброс порта | DNAT на KVM-роутере | Samba доступна из WAN через порт 445 |
## Быстрый запуск (после перезагрузки)
```bash
cd ~/lab-network-stand
sudo ./lab_01_cleanup.sh && \
sudo ./lab_02_bridges.sh && \
sudo ./lab_03_netns.sh && \
sudo ./lab_04_clients.sh && \
sudo ./lab_05_router2.sh && \
sudo ./lab_06_kvm_router.sh && \
sudo ./lab_07_dhcp_clients.sh && \
./lab_08_check.sh && \
sudo ./lab_10_samba_start.sh && \
./lab_09_firewall.sh
Скрипты
Блок	Скрипт	Назначение
1	lab_01_cleanup.sh	Очистка процессов, netns, мостов
2	lab_02_bridges.sh	Создание мостов и NAT на хосте
3	lab_03_netns.sh	Создание netns и DNS
4	lab_04_clients.sh	Подключение PC-A и PC-B к мостам
5	lab_05_router2.sh	Router2 (netns) с FRR и DHCP
6	lab_06_kvm_router.sh	Запуск KVM-роутера
7	lab_07_dhcp_clients.sh	DHCP и маршруты для клиентов
8	lab_08_check.sh	Проверка связи PC-A ↔ PC-B, интернет
9	lab_09_firewall.sh	Файрвол и проброс порта Samba
10	lab_10_samba_start.sh	Запуск и настройка Samba-сервера
11	lab_11_backup.sh	Резервное копирование ВМ
12	lab_12_restore.sh	Восстановление ВМ из копии
Ветки Git
main — стабильная версия

feature/docker — эксперименты с Docker (Router2 в контейнере — нестабильно, откачен. Docker будет использоваться для веб-серверов)

Автоматизация
lab_startup_chain.sh — скрипт для автозапуска

lab-startup.service — systemd-сервис для запуска при загрузке


## Видеодемонстрация

Полная запись развёртывания стенда (10 частей, склеены в один файл):

[final-lab-stand.webm](video/final-lab-stand.webm)

Автор
Роман, 2026



