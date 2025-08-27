#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide the backup file to restore\033[0m"
    echo "Usage: $0 <backup_file.sql.gz>"
    echo "Available backups:"
    ls -1 *.sql.gz
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Error: Backup file $BACKUP_FILE not found\033[0m"
    exit 1
fi

echo -e "${YELLOW}Restoring database from $BACKUP_FILE...\033[0m"

# Decompress if needed
if [[ "$BACKUP_FILE" == *.gz ]]; then
    gunzip -c "$BACKUP_FILE" | docker compose exec -T mysql mysql -u"gitea" -p"gitea"
else
    cat "$BACKUP_FILE" | docker compose exec -T mysql mysql -u"gitea" -p"gitea"
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Database restored successfully\033[0m"
else
    echo -e "${RED}Failed to restore database\033[0m"
    exit 1
fi
