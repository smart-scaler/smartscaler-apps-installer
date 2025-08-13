#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}K3s Deployment Setup Script${NC}"
echo "=================================="

# Check Python3 and pip3 installation
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Python3 is not installed. Please install Python3 first.${NC}"
    exit 1
fi

if ! command -v pip3 &> /dev/null; then
    echo -e "${RED}pip3 is not installed. Please install pip3 first.${NC}"
    exit 1
fi

# Check and install required Python packages
echo "Checking required Python packages..."
python3 -c "
import sys
import subprocess

required_packages = ['pyyaml', 'jinja2']
installed_packages = subprocess.check_output([sys.executable, '-m', 'pip', 'freeze']).decode().split('\n')
installed_packages = [pkg.split('==')[0].lower() for pkg in installed_packages if pkg]

missing_packages = [pkg for pkg in required_packages if pkg.lower() not in installed_packages]

if missing_packages:
    print(f'Installing missing packages: {missing_packages}')
    for package in missing_packages:
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', package])
else:
    print('All required packages are installed.')
"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to install required Python packages${NC}"
    exit 1
fi

# Setup locale
echo "Setting up locale..."
if ! locale -a | grep -q "en_US.utf8"; then
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run as root to setup locale${NC}"
        exit 1
    fi
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y locales
    locale-gen en_US.UTF-8
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
fi

# Export locale variables
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo "Checking if K3s deployment is enabled..."

# Check if k3s deployment is enabled
K3S_ENABLED=$(python3 -c '
import yaml
import sys
import os

try:
    with open("user_input.yml", "r") as f:
        data = yaml.safe_load(f)
        if "k3s_deployment" not in data:
            print("Error: k3s_deployment section not found in user_input.yml", file=sys.stderr)
            sys.exit(1)
        if "enabled" not in data["k3s_deployment"]:
            print("Error: enabled field not found in k3s_deployment section", file=sys.stderr)
            sys.exit(1)
        print(str(data["k3s_deployment"]["enabled"]).lower())
except FileNotFoundError:
    print("Error: user_input.yml file not found", file=sys.stderr)
    sys.exit(1)
except yaml.YAMLError as e:
    print(f"Error parsing YAML: {str(e)}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"Error reading YAML: {str(e)}", file=sys.stderr)
    sys.exit(1)
')

if [ $? -ne 0 ]; then
    echo -e "${RED}Error checking K3s deployment status${NC}"
    exit 1
fi

if [ "$K3S_ENABLED" != "true" ]; then
    echo -e "${RED}K3s deployment is disabled in user_input.yml. Skipping setup.${NC}"
    exit 0
fi

echo -e "${GREEN}K3s deployment is enabled. Proceeding with setup...${NC}"

# Check if kubernetes_deployment section exists (required for node info)
K8S_SECTION_EXISTS=$(python3 -c '
import yaml
import sys

try:
    with open("user_input.yml", "r") as f:
        data = yaml.safe_load(f)
        if "kubernetes_deployment" in data:
            print("true")
        else:
            print("false")
except Exception as e:
    print("false")
')

if [ "$K8S_SECTION_EXISTS" != "true" ]; then
    echo -e "${RED}Error: kubernetes_deployment section is required for K3s deployment${NC}"
    echo "K3s deployment uses the same node configuration as kubespray deployment."
    exit 1
fi

# Create necessary directories
echo "Creating necessary directories..."
mkdir -p inventory/k3s
mkdir -p output

# Ensure ansible.log file exists and is writable
touch output/ansible.log
chmod 666 output/ansible.log

# Add a separator and timestamp to the log file
echo "" >> output/ansible.log
echo "==================================================================================" >> output/ansible.log
echo "K3S DEPLOYMENT STARTED: $(date)" >> output/ansible.log
echo "==================================================================================" >> output/ansible.log
echo "" >> output/ansible.log

# Check if k3s-ansible directory exists, if not clone it
if [ ! -d "k3s-ansible" ] || [ ! -d "k3s-ansible/.git" ]; then
    echo "Cloning k3s-ansible repository..."
    if [ -d "k3s-ansible" ]; then
        rm -rf k3s-ansible
    fi
    
    git clone https://github.com/k3s-io/k3s-ansible.git
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to clone k3s-ansible repository${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ K3s-ansible repository cloned successfully${NC}"
else
    echo -e "${YELLOW}K3s-ansible repository already exists. Updating...${NC}"
    cd k3s-ansible
    git fetch origin
    git reset --hard origin/master
    cd ..
    echo -e "${GREEN}✓ K3s-ansible repository updated successfully${NC}"
fi

# Generate K3s inventory and configuration
echo "Generating K3s configuration files..."

python3 generate_k3s_config.py

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to generate K3s configuration files${NC}"
    exit 1
fi

echo -e "${GREEN}✓ K3s setup completed successfully!${NC}"

# Check if ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}ansible-playbook command not found. Please install Ansible first.${NC}"
    exit 1
fi

# Test SSH connectivity to all nodes
echo -e "\n${YELLOW}Testing SSH connectivity to all nodes...${NC}"
python3 test_ssh_connectivity.py

if [ $? -ne 0 ]; then
    echo -e "${RED}SSH connectivity test failed.${NC}"
    exit 1
fi

echo -e "\n${GREEN}SSH connectivity test passed for all nodes.${NC}"

# Run the Ansible playbook
echo -e "\nStarting K3s deployment..."
echo -e "${YELLOW}Using generated K3s configuration:${NC}"
echo "  - Inventory: inventory/k3s/inventory.yml"
echo "  - Group Variables: inventory/k3s/group_vars/all.yml"
echo ""

# Ensure locale is set for Ansible
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

# Run K3s deployment with generated inventory and group_vars using local k3s-ansible
# Copy our generated inventory to k3s-ansible directory
cp inventory/k3s/inventory.yml k3s-ansible/
cp -r inventory/k3s/group_vars k3s-ansible/

# Run K3s deployment with generated inventory and group_vars using local k3s-ansible
# Copy our generated inventory to k3s-ansible directory
cp inventory/k3s/inventory.yml k3s-ansible/
cp -r inventory/k3s/group_vars k3s-ansible/

# Run from k3s-ansible directory to ensure roles are found
echo -e "\n${YELLOW}Starting K3s deployment with Ansible...${NC}"
echo -e "Logs will be written to: ${GREEN}output/ansible.log${NC}"
echo ""

cd k3s-ansible
# Use the main ansible.cfg to ensure proper logging
export ANSIBLE_CONFIG=../ansible.cfg
ansible-playbook playbooks/site.yml \
    -i inventory.yml \
    -e @../user_input.yml \
    --become \
    --become-user=root \
    -vvv

# Return to original directory
cd ..

if [ $? -ne 0 ]; then
    echo -e "${RED}K3s deployment failed.${NC}"
    # Add failure marker to log
    echo "K3S DEPLOYMENT FAILED: $(date)" >> output/ansible.log
    exit 1
fi

# Add completion marker to log
echo "K3S DEPLOYMENT COMPLETED SUCCESSFULLY: $(date)" >> output/ansible.log

# Copy kubeconfig from remote control plane node
echo -e "\n${YELLOW}Copying kubeconfig from remote control plane node...${NC}"

# Get the control plane node details from user_input.yml
CONTROL_PLANE_IP=$(python3 -c "
import yaml
with open('user_input.yml', 'r') as f:
    data = yaml.safe_load(f)
cp_nodes = data['kubernetes_deployment']['control_plane_nodes']
print(cp_nodes[0]['ansible_host'])
")

CONTROL_PLANE_USER=$(python3 -c "
import yaml
with open('user_input.yml', 'r') as f:
    data = yaml.safe_load(f)
cp_nodes = data['kubernetes_deployment']['control_plane_nodes']
print(cp_nodes[0].get('ansible_user', 'root'))
")

SSH_KEY_PATH=$(python3 -c "
import yaml
with open('user_input.yml', 'r') as f:
    data = yaml.safe_load(f)
print(data['kubernetes_deployment']['ssh_key_path'])
")

echo -e "Copying kubeconfig from ${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}..."

# Try to copy kubeconfig from the remote node
if scp -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}:/etc/rancher/k3s/k3s.yaml" "output/k3s-kubeconfig" 2>/dev/null; then
    echo -e "${GREEN}✓ Kubeconfig copied from /etc/rancher/k3s/k3s.yaml${NC}"
    
    # Fix the kubeconfig IP address (replace 127.0.0.1 with actual server IP)
    echo -e "\n${YELLOW}Fixing kubeconfig IP address...${NC}"
    if grep -q "127.0.0.1" output/k3s-kubeconfig; then
        # Replace 127.0.0.1 with actual IP
        sed -i "s/127.0.0.1/${CONTROL_PLANE_IP}/g" output/k3s-kubeconfig
        echo -e "${GREEN}✓ Updated kubeconfig IP from 127.0.0.1 to ${CONTROL_PLANE_IP}${NC}"
    else
        echo -e "${GREEN}✓ Kubeconfig IP is already correct${NC}"
    fi
elif scp -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}:~/.kube/config" "output/k3s-kubeconfig" 2>/dev/null; then
    echo -e "${GREEN}✓ Kubeconfig copied from ~/.kube/config${NC}"
    
    # Fix the kubeconfig IP address if needed
    echo -e "\n${YELLOW}Fixing kubeconfig IP address...${NC}"
    if grep -q "127.0.0.1" output/k3s-kubeconfig; then
        sed -i "s/127.0.0.1/${CONTROL_PLANE_IP}/g" output/k3s-kubeconfig
        echo -e "${GREEN}✓ Updated kubeconfig IP from 127.0.0.1 to ${CONTROL_PLANE_IP}${NC}"
    else
        echo -e "${GREEN}✓ Kubeconfig IP is already correct${NC}"
    fi
else
    echo -e "${RED}Error: Could not copy kubeconfig from remote node${NC}"
    echo -e "${YELLOW}Tried locations:${NC}"
    echo -e "  - /etc/rancher/k3s/k3s.yaml"
    echo -e "  - ~/.kube/config"
    echo -e "${YELLOW}SSH command used:${NC}"
    echo -e "  scp -i ${SSH_KEY_PATH} ${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}:<path> output/k3s-kubeconfig"
    echo -e "${YELLOW}Please check:${NC}"
    echo -e "  1. SSH key permissions and path"
    echo -e "  2. Remote node connectivity"
    echo -e "  3. K3s installation status on remote node"
fi

echo -e "${GREEN}K3s deployment completed successfully!${NC}"
echo -e "Kubeconfig file will be available at: ${GREEN}output/k3s-kubeconfig${NC}"
echo ""
echo -e "${YELLOW}Cluster Information:${NC}"
echo "  - Cluster Name: smart-scaler-k3s-$(python3 -c "
import yaml
with open('user_input.yml', 'r') as f:
    data = yaml.safe_load(f)
cp_nodes = data['kubernetes_deployment']['control_plane_nodes']
print(cp_nodes[0]['name'])
")"
echo "  - API Endpoint: $(python3 -c "
import yaml
with open('user_input.yml', 'r') as f:
    data = yaml.safe_load(f)
cp_nodes = data['kubernetes_deployment']['control_plane_nodes']
print(cp_nodes[0]['ansible_host'])
"):6443"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Export kubeconfig: export KUBECONFIG=\$PWD/output/k3s-kubeconfig"
echo "2. Verify cluster: kubectl get nodes"
echo "3. Check system pods: kubectl get pods -n kube-system"
echo "4. Test cluster access: kubectl cluster-info"
echo ""
echo -e "${GREEN}Configuration files generated:${NC}"
echo "  - inventory/k3s/inventory.yml"
echo "  - inventory/k3s/group_vars/all.yml"
echo ""
echo -e "${GREEN}Logs written to:${NC}"
echo "  - output/ansible.log (Ansible execution logs)"
echo ""
echo -e "${YELLOW}Note:${NC} K3s deployment uses the same node configuration as kubespray deployment"
echo "from the kubernetes_deployment section in user_input.yml"
