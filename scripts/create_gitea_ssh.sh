#!/bin/bash

# Configuration
REPO_KEY_DIR=".gitea/ssh"
KEY_NAME="gitea_deploy_key"
KEY_PATH="${REPO_KEY_DIR}/${KEY_NAME}"
EMAIL="admin@example.com"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up SSH key for Gitea...${NC}"

# Create .gitea/ssh directory if it doesn't exist
mkdir -p "$REPO_KEY_DIR"

# Generate SSH key if it doesn't exist
if [ ! -f "${KEY_PATH}" ]; then
    echo -e "${YELLOW}Generating new SSH key...${NC}"
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_PATH" -N ""
else
    echo -e "${YELLOW}Using existing SSH key...${NC}"
fi

# Add to SSH config
echo -e "${YELLOW}Adding SSH config for Gitea...${NC}"
SSH_CONFIG="$REPO_KEY_DIR/config"
cat > "$SSH_CONFIG" << EOL
# Gitea local configuration
Host localhost-gitea
    HostName localhost
    Port 2222
    User git
    IdentityFile $(pwd)/${KEY_PATH}
    StrictHostKeyChecking no
EOL

# Create a script to set up SSH for other users
cat > "$REPO_KEY_DIR/setup_ssh.sh" << 'EOL'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p ~/.ssh
cat "$SCRIPT_DIR/config" >> ~/.ssh/config
chmod 600 "$SCRIPT_DIR/gitea_deploy_key"*
echo "SSH configuration added to ~/.ssh/config"
echo "You can now use git with SSH for this repository"
EOL

chmod +x "$REPO_KEY_DIR/setup_ssh.sh"

# Create .gitignore to protect private key
if [ ! -f "$REPO_KEY_DIR/.gitignore" ]; then
    echo -e "${YELLOW}Creating .gitignore for SSH keys...${NC}"
    cat > "$REPO_KEY_DIR/.gitignore" << EOL
# Ignore private key
gitea_deploy_key
EOL
fi

# Display the public key
echo -e "${GREEN}✅ SSH key setup completed!${NC}"
echo -e "${YELLOW}Here's your public key to add to Gitea:${NC}"
echo ""
cat "${KEY_PATH}.pub"
echo ""
echo -e "${YELLOW}Instructions:${NC}"
echo "1. Copy the public key above"
echo "2. Go to http://localhost:3002/user/settings/keys"
echo "3. Click 'Add Key'"
echo "4. Paste the key and give it a title"
echo "5. Click 'Add Key' to save"
echo ""
echo -e "${YELLOW}To test the connection after adding the key, run:${NC}"
echo "ssh -F ${SSH_CONFIG} git@localhost-gitea"
echo ""
echo -e "${YELLOW}For new users:${NC}"
echo "Run .gitea/ssh/setup_ssh.sh to configure SSH for this repository"