#!/bin/bash

# Получаем глобальный IPv6-адрес (исключаем локальные fe80::)
IPV6_ADDR=$(ip -6 addr show scope global | grep -oP '(?<=inet6 )[^/]+')

# Если IPv6-адрес найден
if [[ -n "$IPV6_ADDR" ]]; then
    echo "Найден IPv6-адрес: $IPV6_ADDR"

    # Определяем интерфейс, к которому привязан этот IPv6
    INTERFACE=$(ip -6 addr show scope global | awk '/inet6/ {print $NF; exit}')

    echo "Используемый интерфейс: $INTERFACE"

    # Создаём резервную копию /etc/network/interfaces
    cp /etc/network/interfaces /etc/network/interfaces.bak

    # Добавляем IPv6 в конфигурацию сети
    cat <<EOL >> /etc/network/interfaces

# Автоматически добавленный IPv6
iface $INTERFACE inet6 static
    address $IPV6_ADDR
    netmask 64
    gateway fe80::1
EOL

    echo "IPv6-адрес добавлен в /etc/network/interfaces"

    # Перезапускаем сеть
    systemctl restart networking
    echo "Сетевые настройки обновлены."
else
    echo "Глобальный IPv6-адрес не найден."
    exit 1
fi
