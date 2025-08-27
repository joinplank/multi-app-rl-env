#!/bin/bash

# Configuration
BACKUP_DIR="backups/mysql"
MYSQL_CONTAINER="mysql"
MYSQL_DATABASE="gitea"
MYSQL_USER="gitea"
MYSQL_PASSWORD="gitea"
DATE=$(date +%Y%m%d_%H%M%S)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo -e "${YELLOW}Starting MySQL backup process...${NC}"

# Check if MySQL container is running
if ! docker compose ps "$MYSQL_CONTAINER" --format json | grep -q "running"; then
    echo -e "${RED}Error: MySQL container is not running${NC}"
    exit 1
fi

# Create SQL dump
echo -e "${YELLOW}Creating SQL dump...${NC}"
DUMP_FILE="${BACKUP_DIR}/gitea_db_${DATE}.sql"
if docker compose exec "$MYSQL_CONTAINER" mysqldump \
    -u"$MYSQL_USER" \
    -p"$MYSQL_PASSWORD" \
    --databases "$MYSQL_DATABASE" \
    --add-drop-database \
    --add-drop-table \
    --create-options \
    --quote-names \
    --single-transaction \
    --quick \
    --set-charset \
    > "$DUMP_FILE"; then
    echo -e "${GREEN}SQL dump created successfully: ${DUMP_FILE}${NC}"
else
    echo -e "${RED}Failed to create SQL dump${NC}"
    exit 1
fi

# Create compressed backup
echo -e "${YELLOW}Creating compressed backup...${NC}"
COMPRESSED_FILE="${DUMP_FILE}.gz"
if gzip -f "$DUMP_FILE"; then
    echo -e "${GREEN}Compressed backup created successfully: ${COMPRESSED_FILE}${NC}"
else
    echo -e "${RED}Failed to create compressed backup${NC}"
    exit 1
fi

# Create restore script
RESTORE_SCRIPT="${BACKUP_DIR}/restore_db.sh"
cat > "$RESTORE_SCRIPT" << EOL
#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ -z "\$1" ]; then
    echo -e "\${RED}Error: Please provide the backup file to restore${NC}"
    echo "Usage: \$0 <backup_file.sql.gz>"
    echo "Available backups:"
    ls -1 *.sql.gz
    exit 1
fi

BACKUP_FILE="\$1"

if [ ! -f "\$BACKUP_FILE" ]; then
    echo -e "\${RED}Error: Backup file \$BACKUP_FILE not found${NC}"
    exit 1
fi

echo -e "\${YELLOW}Restoring database from \$BACKUP_FILE...${NC}"

# Decompress if needed
if [[ "\$BACKUP_FILE" == *.gz ]]; then
    gunzip -c "\$BACKUP_FILE" | docker compose exec -T mysql mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD"
else
    cat "\$BACKUP_FILE" | docker compose exec -T mysql mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD"
fi

if [ \$? -eq 0 ]; then
    echo -e "\${GREEN}Database restored successfully${NC}"
else
    echo -e "\${RED}Failed to restore database${NC}"
    exit 1
fi
EOL

chmod +x "$RESTORE_SCRIPT"

# List backup files
echo -e "\n${GREEN}Backup completed successfully!${NC}"
echo -e "${YELLOW}Backup files:${NC}"
ls -lh "$BACKUP_DIR"/*.gz

echo -e "\n${YELLOW}To restore a backup, run:${NC}"
echo "cd $BACKUP_DIR"
echo "./restore_db.sh <backup_file.sql.gz>"
