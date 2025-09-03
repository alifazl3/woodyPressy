#!/bin/bash
set -e

# Usage: ./new-wordpress.sh [path-to-compose-file]
# Default compose file is apple-silicon/docker-compose.yml

COMPOSE_FILE="${1:-apple-silicon/docker-compose.yml}"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "Compose file '$COMPOSE_FILE' not found" >&2
  exit 1
fi

PROJECT="wp$(date +%s)"

docker compose -f "$COMPOSE_FILE" -p "$PROJECT" up -d

echo "Service ports:"
printf "  - WordPress:  %s\n" "$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT" port wordpress 80)"
printf "  - MySQL:      %s\n" "$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT" port db 3306)"
printf "  - phpMyAdmin: %s\n" "$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT" port phpmyadmin 80)"

