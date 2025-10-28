#!/usr/bin/env bash
# Re-exec with bash if not already running under bash
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

# --- helpers ---
require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Error: '$1' not found."; exit 1; }; }
require_cmd openssl
require_cmd docker-compose

check_port() {
  local port=$1
  if command -v ss >/dev/null 2>&1; then
    ss -tuln | awk '{print $5}' | grep -E -q "[:.]${port}\$" && return 1
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tuln | awk '{print $4}' | grep -E -q "[:.]${port}\$" && return 1
  else
    echo "Error: Neither ss nor netstat is available to check ports." >&2
    exit 1
  fi
  return 0
}

generate_free_port() {
  local start=$1 end=$2 port
  while :; do
    port=$((RANDOM % (end - start + 1) + start))
    if check_port "$port"; then echo "$port"; return; fi
  done
}

cleanup() {
  if [ -n "${WORK_DIR:-}" ] && [ -d "${WORK_DIR}" ]; then
    echo "Stopping Docker Compose services in ${WORK_DIR}..."
    (cd "${WORK_DIR}" && docker-compose down) || true
  else
    docker-compose down || true
  fi
  echo "Services stopped and cleaned up."
}
trap cleanup SIGINT SIGTERM

# --- modes ---
# STRICT ARG MODE:
# If an argument (directory) is provided:
#   - If directory exists and has .env => reuse it (bring instance up)
#   - If directory exists but no .env => EXIT with error (do NOT create new)
#   - If directory does not exist => EXIT with error (do NOT create new)
#
# NO-ARG MODE:
#   - Create a fresh instance under wp_instance_<timestamp>

if [ $# -ge 1 ]; then
  TARGET_DIR="$1"
  if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist. Won't create a new one in arg mode."
    exit 1
  fi

  cd "$TARGET_DIR"
  WORK_DIR="$(pwd)"

  if [ ! -f .env ]; then
    echo "Error: '.env' not found in '$WORK_DIR'. This looks not like a previously created instance."
    echo "Tip: run without arguments to create a new instance, or pass a directory that contains a valid .env."
    exit 1
  fi

  # Load .env
  set -o allexport
  # shellcheck disable=SC1091
  source .env
  set +o allexport

  # Minimal sanity checks
  : "${INSTANCE_NAME:?Missing INSTANCE_NAME in .env}"
  : "${PORT_WP:?Missing PORT_WP in .env}"
  : "${PORT_PMA:?Missing PORT_PMA in .env}"
  : "${MYSQL_PASSWORD:?Missing MYSQL_PASSWORD in .env}"
  : "${MYSQL_ROOT_PASSWORD:?Missing MYSQL_ROOT_PASSWORD in .env}"

else
  INSTANCE_NAME="wp_instance_$(date +%s)"
  TARGET_DIR="${INSTANCE_NAME}"
  mkdir -p "${TARGET_DIR}"
  cd "${TARGET_DIR}"
  WORK_DIR="$(pwd)"

  PORT_WP=$(generate_free_port 8000 8999)
  PORT_PMA=$(generate_free_port 9000 9999)
  MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
  MYSQL_PASSWORD=$(openssl rand -base64 12)

  cat > .env <<EOL
INSTANCE_NAME=${INSTANCE_NAME}
PORT_WP=${PORT_WP}
PORT_PMA=${PORT_PMA}
WORDPRESS_DB_HOST=db
WORDPRESS_DB_NAME=wordpress
WORDPRESS_DB_USER=wordpress
WORDPRESS_DB_PASSWORD=${MYSQL_PASSWORD}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=${MYSQL_PASSWORD}
EOL
fi

# Prepare data dirs/files (idempotent)
mkdir -p "${INSTANCE_NAME}/wordpress" "${INSTANCE_NAME}/mysql"
touch "${INSTANCE_NAME}/php.ini"

# Create/update landing HTML
cat > "${INSTANCE_NAME}/index.html" <<EOL
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>WordPress Instance: ${INSTANCE_NAME}</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
    .container { max-width: 800px; margin: auto; }
    h1 { color: #333; }
    ul { list-style: none; padding: 0; }
    li { margin: 15px 0; font-size: 1.1em; }
    a { text-decoration: none; }
    pre { background: #fff; padding: 15px; border-radius: 6px; box-shadow: 0 2px 4px rgba(0,0,0,.1); }
  </style>
</head>
<body><div class="container">
  <h1>WordPress Instance: ${INSTANCE_NAME}</h1>
  <h2>Service URLs</h2>
  <ul>
    <li><strong>WordPress:</strong> <a href="http://localhost:${PORT_WP}" target="_blank">http://localhost:${PORT_WP}</a></li>
    <li><strong>phpMyAdmin:</strong> <a href="http://localhost:${PORT_PMA}" target="_blank">http://localhost:${PORT_PMA}</a></li>
  </ul>
  <h2>Database Credentials</h2>
  <pre>Host: db
Name: wordpress
User: wordpress
Password: ${MYSQL_PASSWORD}
Root Password: ${MYSQL_ROOT_PASSWORD}</pre>
  <p><strong>Note:</strong> Keep these credentials secure and do not share publicly.</p>
</div></body>
</html>
EOL

# Ensure docker-compose.yml exists
if [ ! -f docker-compose.yml ]; then
  cat > docker-compose.yml <<'YAML'
version: "3.8"
services:
  db:
    image: mysql:8.0
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - ./mysql:/var/lib/mysql
  wordpress:
    image: wordpress:php8.0-apache
    depends_on:
      - db
    ports:
      - "${PORT_WP}:80"
    environment:
      WORDPRESS_DB_HOST: ${WORDPRESS_DB_HOST}
      WORDPRESS_DB_USER: ${WORDPRESS_DB_USER}
      WORDPRESS_DB_PASSWORD: ${WORDPRESS_DB_PASSWORD}
      WORDPRESS_DB_NAME: ${WORDPRESS_DB_NAME}
    volumes:
      - ./wordpress:/var/www/html
  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    depends_on:
      - db
    ports:
      - "${PORT_PMA}:80"
    environment:
      PMA_HOST: db
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
YAML
fi

echo "Bringing up services in ${WORK_DIR}..."
docker-compose up -d

ABS_HTML="file://$(pwd)/${INSTANCE_NAME}/index.html"
cat <<INFO

=== Service Information ===
Instance Name: ${INSTANCE_NAME}
Directory: ${WORK_DIR}
WordPress: http://localhost:${PORT_WP}
phpMyAdmin: http://localhost:${PORT_PMA}
HTML Page: ${ABS_HTML}
Database Credentials:
  Host: db
  Name: wordpress
  User: wordpress
  Password: ${MYSQL_PASSWORD}
  Root Password: ${MYSQL_ROOT_PASSWORD}
=========================

INFO

while true; do sleep 1; done