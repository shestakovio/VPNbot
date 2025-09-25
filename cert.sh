#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="/opt/caddy/docker-compose.yml"
HOST_DIR="/opt/caddy"
CERTS_DIR="$HOST_DIR/certs"
CADDYFILE="$HOST_DIR/Caddyfile"

# ✅ Укажи свой репозиторий и ветку
REPO="epsiont/certs"
BRANCH="main"

KEY_SRC="STAR.portal-guard.com_key.txt"
CRT_SRC="STAR.portal-guard.com.crt"

KEY_NAME="STAR.portal-guard.com.key"
CRT_NAME="STAR.portal-guard.com.crt"

MARKER_START="# >>> SELF_STEAL_PORT BLOCK START"
MARKER_END="# <<< SELF_STEAL_PORT BLOCK END"

# Проверка токена
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "❌ Ошибка: переменная GITHUB_TOKEN не установлена!"
  echo "Сделай: export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxx"
  exit 1
fi

# 1. Добавляем volumes в docker-compose.yml
if ! grep -q "./certs:/etc/caddy/certs" "$COMPOSE_FILE"; then
  echo "Добавляю volumes в $COMPOSE_FILE..."
  awk '
    BEGIN {added=0}
    /volumes:/ && added==0 {
      print $0 "\n      - ./certs:/etc/caddy/certs"
      added=1
      next
    }
    {print}
  ' "$COMPOSE_FILE" > "$COMPOSE_FILE.tmp" && mv "$COMPOSE_FILE.tmp" "$COMPOSE_FILE"
else
  echo "volumes уже есть в $COMPOSE_FILE"
fi

# 2. Скачиваем сертификаты из приватного репо
mkdir -p "$CERTS_DIR"

echo "Качаю ключ..."
curl -fsSL \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3.raw" \
  "https://api.github.com/repos/$REPO/contents/$KEY_SRC?ref=$BRANCH" \
  -o "$CERTS_DIR/$KEY_NAME"

echo "Качаю сертификат..."
curl -fsSL \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3.raw" \
  "https://api.github.com/repos/$REPO/contents/$CRT_SRC?ref=$BRANCH" \
  -o "$CERTS_DIR/$CRT_NAME"

chmod 600 "$CERTS_DIR/$KEY_NAME"
chmod 644 "$CERTS_DIR/$CRT_NAME"

# 3. Обновляем Caddyfile
[ -f "$CADDYFILE" ] || touch "$CADDYFILE"
cp -a "$CADDYFILE" "${CADDYFILE}.bak.$(date +%Y%m%d%H%M%S)"

read -r -d '' CADDY_BLOCK <<EOM

:{$SELF_STEAL_PORT} {
    tls /etc/caddy/certs/$CRT_NAME /etc/caddy/certs/$KEY_NAME
    respond 204
    log off
}
EOM

BLOCK_TO_INSERT="${MARKER_START}
${CADDY_BLOCK}
${MARKER_END}"

if grep -qF "$MARKER_START" "$CADDYFILE"; then
  echo "Обновляю блок в $CADDYFILE..."
  awk -v start="$MARKER_START" -v end="$MARKER_END" -v repl="$CADDY_BLOCK" '
    BEGIN { inblock=0 }
    {
      if ($0 == start) { print start; print repl; inblock=1; next }
      if ($0 == end)   { print end; inblock=0; next }
      if (!inblock)    print $0
    }' "$CADDYFILE" > "$CADDYFILE.tmp" && mv "$CADDYFILE.tmp" "$CADDYFILE"
else
  echo "Добавляю новый блок в $CADDYFILE..."
  printf "\n%s\n" "$BLOCK_TO_INSERT" >> "$CADDYFILE"
fi

# 4. Пересобираем контейнер
echo "Пересобираю контейнер..."
docker compose -f "$COMPOSE_FILE" up -d --force-recreate

echo "✅ Готово!"
echo "   Сертификаты: $CERTS_DIR/$CRT_NAME, $CERTS_DIR/$KEY_NAME"
echo "   Caddyfile:   $CADDYFILE"
echo "   Контейнер пересобран"
