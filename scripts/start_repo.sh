#!/bin/bash

# Configuration
GITEA_URL="http://localhost:3002"
GITEA_USER="gitea_admin"
GITEA_PASSWORD="gitea_admin_password"
REPO_NAME="rl-ym-use-case"
REPO_DESCRIPTION="RL Gym Use Case Implementation"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Starting repository creation process..."

# Wait for Gitea to be ready
echo -e "${YELLOW}Waiting for Gitea to be available...${NC}"
max_retries=30
count=0
while ! curl -s "${GITEA_URL}/api/v1/version" > /dev/null; do
    if [ $count -eq $max_retries ]; then
        echo -e "${RED}Timeout waiting for Gitea to be available${NC}"
        exit 1
    fi
    echo "Waiting... ($(($max_retries - $count)) attempts remaining)"
    sleep 5
    count=$((count + 1))
done

# Check if Gitea needs initial setup
echo -e "${YELLOW}Checking if Gitea needs initial setup...${NC}"
if ! curl -s "${GITEA_URL}/api/v1/users/${GITEA_USER}" | grep -q "username"; then
    echo -e "${YELLOW}Performing initial Gitea setup...${NC}"
    
    # Wait for MySQL to be ready
    echo -e "${YELLOW}Waiting for MySQL to be ready...${NC}"
    sleep 10
    
    # Perform initial setup
    SETUP_RESPONSE=$(curl -X POST "${GITEA_URL}/install" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "db_type=mysql" \
        --data-urlencode "db_host=mysql:3306" \
        --data-urlencode "db_user=gitea" \
        --data-urlencode "db_passwd=gitea" \
        --data-urlencode "db_name=gitea" \
        --data-urlencode "ssl_mode=disable" \
        --data-urlencode "app_name=Gitea" \
        --data-urlencode "repo_root_path=/data/git/repositories" \
        --data-urlencode "lfs_root_path=/data/git/lfs" \
        --data-urlencode "run_user=git" \
        --data-urlencode "domain=localhost" \
        --data-urlencode "ssh_port=22" \
        --data-urlencode "http_port=3000" \
        --data-urlencode "app_url=${GITEA_URL}" \
        --data-urlencode "log_root_path=/data/gitea/log" \
        --data-urlencode "admin_name=${GITEA_USER}" \
        --data-urlencode "admin_passwd=${GITEA_PASSWORD}" \
        --data-urlencode "admin_confirm_passwd=${GITEA_PASSWORD}" \
        --data-urlencode "admin_email=admin@example.com")

    if echo "$SETUP_RESPONSE" | grep -q "error"; then
        echo -e "${RED}Failed to perform initial setup. Response was:${NC}"
        echo "$SETUP_RESPONSE"
        exit 1
    fi

    echo -e "${GREEN}Initial setup completed successfully${NC}"
    
    # Wait for Gitea to restart
    echo -e "${YELLOW}Waiting for Gitea to restart...${NC}"
    sleep 15
fi

# Get access token
echo -e "${YELLOW}Creating access token...${NC}"
TOKEN_RESPONSE=$(curl -s -X POST "${GITEA_URL}/api/v1/users/${GITEA_USER}/tokens" \
    -H "Content-Type: application/json" \
    -u "${GITEA_USER}:${GITEA_PASSWORD}" \
    -d "{\"name\":\"repo-init-token\", \"scopes\": [\"write:repository\", \"repo\"]}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"sha1":"[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
    echo -e "${RED}Failed to get access token. Response was:${NC}"
    echo "$TOKEN_RESPONSE"
    exit 1
fi

echo -e "${GREEN}Successfully obtained access token${NC}"

# Create repository
echo -e "${YELLOW}Creating repository ${REPO_NAME}...${NC}"
REPO_RESPONSE=$(curl -s -X POST "${GITEA_URL}/api/v1/user/repos" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Authorization: token ${ACCESS_TOKEN}" \
    -d "{
        \"name\": \"${REPO_NAME}\",
        \"description\": \"${REPO_DESCRIPTION}\",
        \"private\": false,
        \"auto_init\": false
    }")

if ! echo "$REPO_RESPONSE" | grep -q "\"name\":\"${REPO_NAME}\""; then
    echo -e "${RED}Failed to create repository. Response was:${NC}"
    echo "$REPO_RESPONSE"
    exit 1
fi

echo -e "${GREEN}Repository created successfully${NC}"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Initialize git repository
echo -e "${YELLOW}Initializing local repository...${NC}"
git init
git config --local user.email "admin@example.com"
git config --local user.name "Gitea Admin"

# Create sample code
echo -e "${YELLOW}Creating sample code...${NC}"
cat > main.py << 'EOL'
import gym
import numpy as np

def main():
    # Create the CartPole environment
    env = gym.make('CartPole-v1')
    
    # Simple random agent
    episodes = 10
    for episode in range(episodes):
        state = env.reset()
        total_reward = 0
        done = False
        
        while not done:
            # Take random action
            action = env.action_space.sample()
            state, reward, done, _ = env.step(action)
            total_reward += reward
            
        print(f"Episode {episode + 1}: Total Reward = {total_reward}")
    
    env.close()

if __name__ == "__main__":
    main()
EOL

# Create requirements.txt
cat > requirements.txt << 'EOL'
gym==0.26.2
numpy==1.24.3
EOL

# Create README.md
cat > README.md << 'EOL'
# Sample RL Project

This is a sample reinforcement learning project using OpenAI Gym.

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Run the sample:
```bash
python main.py
```

The sample implements a random agent playing CartPole-v1.
EOL

# Add and commit files
git add .
git commit -m "Initial commit: Basic RL setup with CartPole environment"

# Set up SSH configuration for this push
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_CONFIG="${SCRIPT_DIR}/.gitea/ssh/config"

if [ ! -f "$SSH_CONFIG" ]; then
    echo -e "${RED}SSH configuration not found. Please run create_gitea_ssh.sh first.${NC}"
    exit 1
fi

# Add remote and push
echo -e "${YELLOW}Pushing code to Gitea...${NC}"
export GIT_SSH_COMMAND="ssh -F ${SSH_CONFIG}"
git remote add origin "git@localhost-gitea:${GITEA_USER}/${REPO_NAME}.git"

if ! git push -u origin master; then
    echo -e "${RED}Failed to push using SSH${NC}"
    exit 1
fi

# Cleanup
cd -
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✅ Repository created and code pushed successfully!${NC}"
echo -e "${GREEN}🌐 Repository URL: ${GITEA_URL}/${GITEA_USER}/${REPO_NAME}${NC}"