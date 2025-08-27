#!/bin/bash

# Configuration
GITEA_URL="http://localhost:3002"
GITEA_USER="gitea_admin"
GITEA_PASSWORD="gitea_admin_password"
REPO_NAME="rl-gym-use-case2"
MYSQL_USER="gitea"
MYSQL_PASSWORD="gitea"
BACKUP_FILE="backups/mysql/gitea_db_20250825_154754.sql.gz"
GITEA_DATA_BACKUP="backups/gitea_full"

HOST_NAME=localhost

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ "$ENV" = "PROD" ]; then
    echo -e "${YELLOW}Setting up for PROD environment...${NC}"
    cp .env_gitea_prod .env_gitea
    cp .env_runner_prod .env_runner
    cp ./prometheus/prometheus.yml_prod ./prometheus/prometheus.yml
    HOST_NAME=swegym.joinplank.com
else
    echo -e "${YELLOW}Setting up for DEV environment...${NC}"
    cp .env_gitea .env_gitea
    cp .env_runner .env_runner
fi

# Source code configuration
SOURCE_CODE_PATH="./rl-gym-use-case"  # Change this to your source code path
if [ ! -d "$SOURCE_CODE_PATH" ]; then
    echo "Error: Source code directory not found at $SOURCE_CODE_PATH"
    exit 1
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Gitea setup process...${NC}"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

# Function to wait for service to be ready
wait_for_service() {
    local url=$1
    local max_attempts=$2
    local attempt=1
    
    echo -e "${YELLOW}Waiting for service at $url...${NC}"
    while ! curl -s "$url" > /dev/null; do
        if [ $attempt -eq $max_attempts ]; then
            echo -e "${RED}Service at $url not available after $max_attempts attempts${NC}"
            return 1
        fi
        echo "Attempt $attempt/$max_attempts..."
        sleep 5
        attempt=$((attempt + 1))
    done
    echo -e "${GREEN}Service is ready!${NC}"
    return 0
}

# Stop and remove existing containers and volumes
echo -e "${YELLOW}Cleaning up existing containers and volumes...${NC}"
docker compose down -v

# Build the image
echo -e "${YELLOW}Building and running the Sample App...${NC}"
cd ./rl-gym-use-case
docker build -t host.docker.internal:3002/rl-gym-app:latest .
docker rm -f rl-gym-app || echo "Container not found, starting new one"
docker run -d --name rl-gym-app --network openai-poc_default -p 3000:3000 host.docker.internal:3002/rl-gym-app:latest
cd ..

# Start MySQL first
echo -e "${YELLOW}Starting MySQL...${NC}"
docker compose up -d mysql
sleep 30

# Wait for MySQL to be healthy
echo -e "${YELLOW}Waiting for MySQL to be healthy...${NC}"
max_attempts=30
attempt=1
while [ $attempt -le $max_attempts ]; do
    if docker compose ps mysql | grep -q "healthy"; then
        echo -e "${GREEN}MySQL is healthy!${NC}"
        break
    fi
    echo "Attempt $attempt/$max_attempts..."
    sleep 5
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    echo -e "${RED}MySQL failed to become healthy${NC}"
    exit 1
fi

# Restore MySQL backup
echo -e "${YELLOW}Restoring MySQL backup...${NC}"

# Create a temporary file for the uncompressed backup if needed
TEMP_SQL_FILE=$(mktemp)
trap 'rm -f "$TEMP_SQL_FILE"' EXIT

# Decompress or copy the backup file based on extension
if [[ "$BACKUP_FILE" == *.gz ]]; then
    echo -e "${YELLOW}Decompressing backup file...${NC}"
    if ! gunzip -c "$BACKUP_FILE" > "$TEMP_SQL_FILE"; then
        echo -e "${RED}Failed to decompress backup file${NC}"
        rm -f "$TEMP_SQL_FILE"
        exit 1
    fi
else
    echo -e "${YELLOW}Copying backup file...${NC}"
    if ! cp "$BACKUP_FILE" "$TEMP_SQL_FILE"; then
        echo -e "${RED}Failed to copy backup file${NC}"
        rm -f "$TEMP_SQL_FILE"
        exit 1
    fi
fi

# Restore the backup
echo -e "${YELLOW}Importing backup into MySQL...${NC}"
if ! docker compose exec -T mysql mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h 0.0.0.0 < "$TEMP_SQL_FILE"; then
    echo -e "${RED}Failed to restore MySQL backup${NC}"
    rm -f "$TEMP_SQL_FILE"
    exit 1
fi

# Clean up
rm -f "$TEMP_SQL_FILE"

echo -e "${GREEN}MySQL backup restored successfully${NC}"

# Build and run the Sample App
echo -e "${YELLOW}Building and running the Sample App...${NC}"
cd ./rl-gym-use-case
docker build -t host.docker.internal:3002/rl-gym-app:latest .
docker rm -f rl-gym-app || echo "Container not found, starting new one"
docker run -d --name rl-gym-app --network openai-poc_default -p 3000:3000 host.docker.internal:3002/rl-gym-app:latest
cd ..
echo -e "${GREEN}Sample App built and running successfully${NC}"

# Start Gitea
echo -e "${YELLOW}Starting Gitea...${NC}"
docker compose up -d gitea

# Wait for Gitea to be available
if ! wait_for_service "$GITEA_URL" 30; then
    echo -e "${RED}Failed to start Gitea${NC}"
    exit 1
fi

# Create the repository if it doesn't exist
echo -e "${YELLOW}Checking if repository exists...${NC}"
if ! curl -s -u "${GITEA_USER}:${GITEA_PASSWORD}" "${GITEA_URL}/api/v1/repos/${GITEA_USER}/${REPO_NAME}" | grep -q "\"name\":\"${REPO_NAME}\""; then
    echo -e "${YELLOW}Creating repository...${NC}"
    curl -X POST "${GITEA_URL}/api/v1/user/repos" \
        -H "accept: application/json" \
        -H "Content-Type: application/json" \
        -u "${GITEA_USER}:${GITEA_PASSWORD}" \
        -d "{
            \"name\": \"${REPO_NAME}\",
            \"description\": \"RL Gym Sample Application\",
            \"private\": false,
            \"auto_init\": false
        }"
else
    echo -e "${YELLOW}Repository already exists${NC}"
fi

# Create a temporary directory for the repository
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}Creating repository in ${TEMP_DIR}...${NC}"

# Copy source code to temp directory
echo -e "${YELLOW}Copying source code from ${SOURCE_CODE_PATH}...${NC}"
cp -r "$SOURCE_CODE_PATH/." "$TEMP_DIR/"

# Initialize git repository in temp directory
cd "$TEMP_DIR"
git init
git config --local user.email "admin@example.com"
git config --local user.name "Gitea Admin"
git add .
git commit -m "Initial commit"

# Generate access token for Git operations
echo -e "${YELLOW}Generating access token...${NC}"
TOKEN_NAME="repo_access_$(date +%s)"
TOKEN_RESPONSE=$(curl -s -X POST "${GITEA_URL}/api/v1/users/${GITEA_USER}/tokens" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -u "${GITEA_USER}:${GITEA_PASSWORD}" \
    -d "{
        \"name\":\"$TOKEN_NAME\",
        \"scopes\": [
            \"write:repository\",
            \"read:repository\",
            \"read:user\"
        ]
    }")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"sha1":"[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
    echo -e "${RED}Failed to generate access token${NC}"
    echo -e "${RED}API Response: $TOKEN_RESPONSE${NC}"
    exit 1
fi

# Verify token has correct permissions
echo -e "${YELLOW}Verifying token permissions...${NC}"

# First verify user access
USER_CHECK=$(curl -s "${GITEA_URL}/api/v1/user" \
    -H "accept: application/json" \
    -H "Authorization: token $ACCESS_TOKEN")

if ! echo "$USER_CHECK" | grep -q "\"login\":\"${GITEA_USER}\""; then
    echo -e "${RED}Token user verification failed${NC}"
    echo -e "${RED}API Response: $USER_CHECK${NC}"
    exit 1
fi

# Then verify repository access
REPO_CHECK=$(curl -s "${GITEA_URL}/api/v1/repos/${GITEA_USER}/${REPO_NAME}" \
    -H "accept: application/json" \
    -H "Authorization: token $ACCESS_TOKEN")

if ! echo "$REPO_CHECK" | grep -q "\"permissions\".*\"push\":true"; then
    echo -e "${RED}Token repository verification failed - missing push permission${NC}"
    echo -e "${RED}API Response: $REPO_CHECK${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Access token generated and verified successfully${NC}"

# Initialize bare repository in Gitea container
echo -e "${YELLOW}Initializing repository in Gitea...${NC}"
REPO_PATH="/data/git/repositories/${GITEA_USER}/${REPO_NAME}.git"
docker compose exec gitea sh -c "
    mkdir -p '$REPO_PATH' && \
    cd '$REPO_PATH' && \
    git init --bare && \
    chown -R git:git ."

# Set up remote with new token
REPO_HTTPS_URL="http://${GITEA_USER}:${ACCESS_TOKEN}@localhost:3002/${GITEA_USER}/${REPO_NAME}.git"
FINAL_REPO_HTTPS_URL="http://${GITEA_USER}:${ACCESS_TOKEN}@${HOST_NAME}:3002/${GITEA_USER}/${REPO_NAME}.git"

if git remote | grep -q "^origin$"; then
    echo -e "${YELLOW}Updating remote 'origin' with new URL...${NC}"
    git remote set-url origin "$REPO_HTTPS_URL"
else
    echo -e "${YELLOW}Adding new remote 'origin'...${NC}"
    git remote add origin "$REPO_HTTPS_URL"
fi

# Push the code
echo -e "${YELLOW}Pushing code to repository...${NC}"
if git push -f -u origin main 2>/dev/null || git push -f -u origin master 2>/dev/null; then
    echo -e "${GREEN}✓ Code pushed to remote repository${NC}"
else
    echo -e "${RED}Failed to push code to remote repository${NC}"
    echo -e "${RED}Please check your Git configuration and try again${NC}"
    exit 1
fi

# Clean up
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✅ Gitea setup completed successfully!${NC}"
echo -e "${GREEN}🌐 Repository URL: ${GITEA_URL}/${GITEA_USER}/${REPO_NAME}${NC}"
echo -e "${GREEN}✓ MySQL backup restored${NC}"
if [ -d "$GITEA_DATA_BACKUP" ] && [ -n "$(ls -A "$GITEA_DATA_BACKUP"/*.tar.gz 2>/dev/null)" ]; then
    echo -e "${GREEN}✓ Gitea data restored${NC}"
fi
echo -e "${GREEN}✓ Access token configured${NC}"
echo -e "${GREEN}✓ Repository initialized${NC}"
echo -e "${GREEN}✓ Source code pushed successfully${NC}"

# Get admin token for runner registration
echo -e "${YELLOW}Getting admin token for runner registration...${NC}"
ADMIN_TOKEN_RESPONSE=$(curl -s -X POST \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -u "${GITEA_USER}:${GITEA_PASSWORD}" \
    "${GITEA_URL}/api/v1/users/${GITEA_USER}/tokens" \
    -d '{"name":"runner_token","scopes":["write:admin"]}')

ADMIN_TOKEN=$(echo "$ADMIN_TOKEN_RESPONSE" | grep -o '"sha1":"[^"]*' | cut -d'"' -f4)

if [ -z "$ADMIN_TOKEN" ]; then
    echo -e "${RED}Failed to get admin token${NC}"
    echo -e "${RED}API Response: $ADMIN_TOKEN_RESPONSE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Got admin token${NC}"

# Get runner registration token using admin token
echo -e "${YELLOW}Getting runner registration token...${NC}"
RUNNER_TOKEN=$(curl -s -H "Authorization: token $ADMIN_TOKEN" -H "accept: application/json" \
    "${GITEA_URL}/api/v1/admin/runners/registration-token" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$RUNNER_TOKEN" ]; then
    echo -e "${RED}Failed to get runner registration token${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Got runner registration token${NC}"


# Start act_runner with the new token
echo -e "${YELLOW}Starting act_runner with new registration token...${NC}"

# Remove existing runner container if it exists
echo -e "${YELLOW}Removing existing runner container if present...${NC}"
# docker rm -f gitea-runner >/dev/null 2>&1 || true

# Replace the sed command with a cross-platform version
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS version
    sed -i '' "s/GITEA_RUNNER_REGISTRATION_TOKEN=.*/GITEA_RUNNER_REGISTRATION_TOKEN=$RUNNER_TOKEN/" .env_runner
else
    # Linux version
    sed -i "s/GITEA_RUNNER_REGISTRATION_TOKEN=.*/GITEA_RUNNER_REGISTRATION_TOKEN=$RUNNER_TOKEN/" .env_runner
fi

# restart act_runner
docker compose restart act_runner

echo -e "${GREEN}✓ Started act_runner with new token${NC}"

# Start containers except act_runner
echo -e "${GREEN}✓ Starting main containers...${NC}"
docker compose up -d


echo

echo -e "${BLUE}--------------------------------${NC}"
echo -e "${GREEN}✓ Setup Completed!${NC}"
echo -e "${BLUE}--------------------------------${NC}"

echo

echo -e "${BLUE}STEP 1: WAIT FOR THE CI/CD PIPELINE TO RUN${NC}"
echo -e "${GREEN}✓ Gitea Workflow: http://$HOST_NAME:3002/gitea_admin/rl-gym-use-case2/actions/runs/1"
echo -e "${GREEN}✓ Gitea User: gitea_admin"
echo -e "${GREEN}✓ Gitea Password: gitea_admin_password"

echo

echo -e "${BLUE}STEP 2: CLONE THE REPO AND INSERT NEW CODE${NC}"
echo -e "${GREEN}✓ Clone the Repo: git clone $FINAL_REPO_HTTPS_URL"

echo

# Grafana url
echo -e "${BLUE}STEP 3: CHECK THE GRAFANA DASHBOARD${NC}"
echo -e "${GREEN}✓ Grafana URL: http://$HOST_NAME:3001/d/rl-gym-performance/rl-gym-app-performance"
echo -e "${GREEN}✓ Grafana User: admin"
echo -e "${GREEN}✓ Grafana Password: admin123"

echo

echo -e "${BLUE}STEP 4: CHECK THE RL-GYM - SAMPLE APP${NC}"
# RL-Gym - Sample App - Available after CI/CD Pipeline has run
echo -e "${GREEN}✓ RL-Gym - Sample App: http://$HOST_NAME:3000/health${NC}"
