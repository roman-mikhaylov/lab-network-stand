FROM ubuntu:22.04

# Неинтерактивная установка
ENV DEBIAN_FRONTEND=noninteractive

# Установка пакетов
RUN apt update && apt install -y \
    frr \
    isc-dhcp-server \
    iproute2 \
    iptables \
    tcpdump \
    && rm -rf /var/lib/apt/lists/*

# Включаем OSPF
RUN sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons

# Копируем конфиги
COPY ospfd.conf /etc/frr/ospfd.conf
COPY zebra.conf /etc/frr/zebra.conf
COPY dhcpd.conf /etc/dhcp/dhcpd.conf
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

# Интерфейсы настраиваются при запуске через docker run --network
EXPOSE 22 179 445 67/udp

CMD ["/startup.sh"]
