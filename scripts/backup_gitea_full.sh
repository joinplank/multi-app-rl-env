#!/bin/bash

# Configuration
BACKUP_DIR="backups/gitea_full"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="gitea_backup_${DATE}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create backup directory
mkdir -p "${BACKUP_DIR}"

echo -e "${YELLOW}Starting full Gitea backup process...${NC}"

# 1. Create MySQL dump
echo -e "${YELLOW}Creating MySQL database dump...${NC}"
if docker compose exec mysql mysqldump -u gitea -pgitea gitea > "${BACKUP_DIR}/${BACKUP_NAME}_db.sql"; then
    echo -e "${GREEN}Database dump created successfully${NC}"
else
    echo -e "${RED}Failed to create database dump${NC}"
    exit 1
fi

# 2. Backup Gitea data volume
echo -e "${YELLOW}Creating Gitea data backup...${NC}"

# Create a temporary container to access the volume
echo -e "${YELLOW}Creating temporary container for volume backup...${NC}"
TEMP_CONTAINER=$(docker create -v gitea_data:/data alpine:latest)

# Copy data from volume to backup directory
echo -e "${YELLOW}Copying data from volume...${NC}"
docker cp "${TEMP_CONTAINER}:/data" "${BACKUP_DIR}/${BACKUP_NAME}_data"

# Remove temporary container
docker rm "${TEMP_CONTAINER}"

# 3. Create compressed archive of everything
echo -e "${YELLOW}Creating compressed archive...${NC}"
cd "${BACKUP_DIR}" && tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}_data" "${BACKUP_NAME}_db.sql"

# 4. Cleanup temporary files
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm -rf "${BACKUP_NAME}_data" "${BACKUP_NAME}_db.sql"

echo -e "${GREEN}✅ Backup completed successfully!${NC}"
echo -e "${GREEN}Backup file: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz${NC}"

# Create restore script
RESTORE_SCRIPT="${BACKUP_DIR}/restore_gitea.sh"
cat > "$RESTORE_SCRIPT" << 'EOL'
#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide the backup file to restore${NC}"
    echo "Usage: $0 <backup_file.tar.gz>"
    echo "Available backups:"
    ls -1 *.tar.gz
    exit 1
fi

BACKUP_FILE="$1"
TEMP_DIR="restore_temp"

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Error: Backup file $BACKUP_FILE not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Starting Gitea restore process...${NC}"

# Create temporary directory
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Extract backup
echo -e "${YELLOW}Extracting backup archive...${NC}"
tar xzf "../$BACKUP_FILE"

# Stop containers
echo -e "${YELLOW}Stopping containers...${NC}"
docker compose down

# Restore database
echo -e "${YELLOW}Restoring database...${NC}"
docker compose up -d mysql
echo "Waiting for MySQL to be ready..."
sleep 20

# Find the database dump file
DB_DUMP=$(find . -name "*_db.sql")
if [ -z "$DB_DUMP" ]; then
    echo -e "${RED}Database dump not found in backup${NC}"
    exit 1
fi

# Restore database
docker compose exec -T mysql mysql -u gitea -pgitea gitea < "$DB_DUMP"

# Restore Gitea data
echo -e "${YELLOW}Restoring Gitea data...${NC}"
DATA_DIR=$(find . -name "*_data")
if [ -z "$DATA_DIR" ]; then
    echo -e "${RED}Data directory not found in backup${NC}"
    exit 1
fi

# Create a temporary container to restore the volume
TEMP_CONTAINER=$(docker create -v gitea_data:/data alpine:latest)
docker cp "$DATA_DIR/." "${TEMP_CONTAINER}:/data"
docker rm "${TEMP_CONTAINER}"

# Start all services
echo -e "${YELLOW}Starting all services...${NC}"
docker compose up -d

# Cleanup
cd ..
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✅ Restore completed successfully!${NC}"
echo -e "${YELLOW}Please wait a few moments for all services to initialize.${NC}"
EOL

chmod +x "$RESTORE_SCRIPT"

echo -e "\n${YELLOW}To restore this backup later:${NC}"
echo "1. cd ${BACKUP_DIR}"
echo "2. ./restore_gitea.sh ${BACKUP_NAME}.tar.gz"
