#!/bin/bash

set -e  # Останавливаем выполнение при ошибке

echo "Обновление списка пакетов..."
apt-get update -y

echo "Обновление системы..."
apt-get upgrade -y

echo "Установка необходимых пакетов..."
apt-get install sudo curl net-tools socat git -y

echo "Клонирование репозитория Marzban-node..."
git clone https://github.com/Gozargah/Marzban-node

echo "Переход в директорию Marzban-node..."
cd Marzban-node

echo "Установка Docker..."
curl -fsSL https://get.docker.com | sh

echo "Создание директории /var/lib/marzban-node/..."
mkdir -p /var/lib/marzban-node/

echo "Удаление старого docker-compose.yml (если существует)..."
rm -f /root/Marzban-node/docker-compose.yml

echo "Загрузка нового docker-compose.yml из репозитория VPNbot..."
curl -fsSL https://raw.githubusercontent.com/shestakovio/VPNbot/refs/heads/main/docker-compose.yml -o /root/Marzban-node/docker-compose.yml

echo
echo "Введите SSL клиентский сертификат (в формате PEM)."
echo "Чтобы завершить ввод, нажмите CTRL+D на новой строке:"
echo

# Чтение ввода и сохранение в файл
cat > /var/lib/marzban-node/ssl_client_cert.pem

echo
echo "Сертификат успешно сохранён в /var/lib/marzban-node/ssl_client_cert.pem"

echo "Установка NODE Exporter..."
mkdir -p /root/node-exporter/
curl -fsSL https://raw.githubusercontent.com/shestakovio/VPNbot/refs/heads/main/node-exporter/docker-compose.yml -o /root/node-exporter/docker-compose.yml

docker compose up -d

echo "Запуск контейнеров через Docker Compose..."
cd /root/Marzban-node
docker compose up -d

echo "Установка и запуск завершены успешно."
