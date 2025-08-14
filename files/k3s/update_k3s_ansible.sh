#!/bin/bash

# update_k3s_ansible.sh
# Helper script to manually update the k3s-ansible repository
# This script will fetch the latest version and preserve customizations

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔄 K3s-ansible Update Script${NC}"
echo "=================================="

# Check if k3s-ansible directory exists (it should be in parent directory)
if [ ! -d "../k3s-ansible" ]; then
    echo -e "${RED}❌ k3s-ansible directory not found${NC}"
    echo "Please run setup_k3s.sh first to create the initial copy."
    exit 1
fi

# Change to parent directory to work with k3s-ansible
cd ..

# Check if it's a git repository
if [ -d "k3s-ansible/.git" ]; then
    echo -e "${YELLOW}⚠️  k3s-ansible is still a git repository${NC}"
    echo "This means it hasn't been converted to a local copy yet."
    echo "Running setup_k3s.sh will handle this automatically."
    exit 1
fi

echo -e "${YELLOW}📋 Current k3s-ansible status:${NC}"
echo "  - Directory: $(pwd)/k3s-ansible"
echo "  - Type: Local copy (no git tracking)"
echo "  - Customizations: $(ls -la k3s-ansible/roles/ | grep -E "(jetson|custom)" | wc -l) custom roles"

# Create backup of current copy
echo -e "\n${YELLOW}💾 Creating backup of current copy...${NC}"
BACKUP_DIR="k3s-ansible.backup.$(date +%Y%m%d_%H%M%S)"
cp -r k3s-ansible "$BACKUP_DIR"
echo -e "${GREEN}✅ Backup created: $BACKUP_DIR${NC}"

# Remove current copy
echo -e "\n${YELLOW}🗑️  Removing current copy...${NC}"
rm -rf k3s-ansible

# Clone fresh copy
echo -e "\n${YELLOW}📥 Cloning fresh k3s-ansible repository...${NC}"
git clone https://github.com/k3s-io/k3s-ansible.git
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to clone k3s-ansible repository${NC}"
    echo "Restoring from backup..."
    mv "$BACKUP_DIR" k3s-ansible
    exit 1
fi

# Detach from git
echo -e "\n${YELLOW}🔓 Detaching from git to maintain local copy...${NC}"
cd k3s-ansible
rm -rf .git
cd ..
echo -e "${GREEN}✅ Git repository detached${NC}"

# Restore customizations from backup
echo -e "\n${YELLOW}🔄 Restoring customizations...${NC}"

# Copy custom roles
if [ -d "$BACKUP_DIR/roles/jetson_prerequisites" ]; then
    echo "  - Restoring Jetson prerequisites role..."
    cp -r "$BACKUP_DIR/roles/jetson_prerequisites" k3s-ansible/roles/
fi

# Copy custom inventory if it exists
if [ -f "$BACKUP_DIR/inventory.yml" ]; then
    echo "  - Restoring custom inventory..."
    cp "$BACKUP_DIR/inventory.yml" k3s-ansible/
fi

# Copy custom group_vars if they exist
if [ -d "$BACKUP_DIR/group_vars" ]; then
    echo "  - Restoring custom group variables..."
    cp -r "$BACKUP_DIR/group_vars" k3s-ansible/
fi

echo -e "${GREEN}✅ Customizations restored${NC}"

# Verify the update
echo -e "\n${YELLOW}🔍 Verifying update...${NC}"
if [ -f "k3s-ansible/playbooks/site.yml" ]; then
    echo -e "${GREEN}✅ k3s-ansible update successful${NC}"
    echo -e "${YELLOW}ℹ️  New copy is now a local version (no git tracking)${NC}"
else
    echo -e "${RED}❌ Update verification failed${NC}"
    echo "Restoring from backup..."
    rm -rf k3s-ansible
    mv "$BACKUP_DIR" k3s-ansible
    exit 1
fi

# Clean up backup (optional)
echo -e "\n${YELLOW}🧹 Cleanup options:${NC}"
echo "1. Keep backup for safety (recommended)"
echo "2. Remove backup to save space"
read -p "Choose option (1 or 2): " choice

case $choice in
    2)
        echo -e "${YELLOW}🗑️  Removing backup...${NC}"
        rm -rf "$BACKUP_DIR"
        echo -e "${GREEN}✅ Backup removed${NC}"
        ;;
    *)
        echo -e "${GREEN}✅ Backup kept at: $BACKUP_DIR${NC}"
        echo "You can remove it manually when you're confident the update is working."
        ;;
esac

echo -e "\n${GREEN}🎉 k3s-ansible update completed successfully!${NC}"
echo -e "${YELLOW}ℹ️  The new copy is now a local version without git tracking${NC}"
echo -e "${YELLOW}ℹ️  Your customizations have been preserved${NC}"
echo -e "${YELLOW}ℹ️  You can now run setup_k3s.sh to deploy with the updated version${NC}"
echo -e "${YELLOW}ℹ️  Update script location: files/k3s/update_k3s_ansible.sh${NC}"
