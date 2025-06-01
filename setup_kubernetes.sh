#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
SSH_KEY_PATH="$HOME/.ssh/k8s_rsa"
INVENTORY_DIR="inventory/kubespray"
INVENTORY_FILE="$INVENTORY_DIR/inventory.ini"
TEMPLATES_DIR="templates"

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

echo "Checking if Kubernetes deployment is enabled..."

# Check if kubernetes deployment is enabled
KUBERNETES_ENABLED=$(python3 -c '
import yaml
try:
    with open("user_input.yml") as f:
        data = yaml.safe_load(f)
    print(str(data.get("kubernetes_deployment", {}).get("enabled", False)).lower())
except:
    print("false")
')

if [ "$KUBERNETES_ENABLED" != "true" ]; then
    echo -e "${RED}Kubernetes deployment is disabled in user_input.yml. Skipping setup.${NC}"
    exit 0
fi

echo "Starting Kubernetes deployment setup..."

# Ensure virtual environment is activated
if [[ -z "${VIRTUAL_ENV}" ]]; then
    if [ -f "venv/bin/activate" ]; then
        echo "Activating Python virtual environment..."
        source venv/bin/activate
    else
        echo -e "${RED}Error: Python virtual environment not found. Please run 'python3 -m venv venv' first.${NC}"
        exit 1
    fi
fi

# Create necessary directories
mkdir -p "$INVENTORY_DIR"

echo "Reading node information from user_input.yml..."

# Check if ansible_user is defined in user_input.yml
DEFAULT_USER=$(python3 -c '
import yaml
try:
    with open("user_input.yml") as f:
        data = yaml.safe_load(f)
    print(data.get("kubernetes_deployment", {}).get("ansible_user", ""))
except:
    print("")
')

# If no default user in yaml, ask for it
if [ -z "$DEFAULT_USER" ]; then
    echo -e "\nNo default ansible_user found in user_input.yml"
    read -p "Enter the default ansible user for all nodes: " DEFAULT_USER
    if [ -z "$DEFAULT_USER" ]; then
        echo -e "${RED}Error: ansible user cannot be empty${NC}"
        exit 1
    fi
fi

# Generate inventory from user_input.yml
python3 << EOF
import yaml
import os
import sys
from jinja2 import Template

try:
    # Read user_input.yml
    with open('user_input.yml', 'r') as f:
        user_input = yaml.safe_load(f)

    # Read the template
    with open('templates/inventory.ini.j2', 'r') as f:
        template_content = f.read()

    # Prepare template variables
    template_vars = {
        'control_plane_nodes': user_input['kubernetes_deployment']['control_plane_nodes'],
        'worker_nodes': user_input['kubernetes_deployment'].get('worker_nodes', []),
        'ssh_key_path': os.path.expanduser('~/.ssh/k8s_rsa'),
        'default_ansible_user': '$DEFAULT_USER'
    }

    # Write inventory file
    os.makedirs('inventory/kubespray', exist_ok=True)
    with open('inventory/kubespray/inventory.ini', 'w') as f:
        template = Template(template_content)
        inventory_content = template.render(**template_vars)
        f.write(inventory_content)

    print("\nSuccessfully generated inventory file.")

    # Print nodes for verification
    print("\nControl Plane Nodes:")
    for node in template_vars['control_plane_nodes']:
        user = node.get('ansible_user', template_vars['default_ansible_user'])
        print(f"  - {node['name']}: {node['ansible_host']} (user: {user})")
    
    if template_vars['worker_nodes']:
        print("\nWorker Nodes:")
        for node in template_vars['worker_nodes']:
            user = node.get('ansible_user', template_vars['default_ansible_user'])
            print(f"  - {node['name']}: {node['ansible_host']} (user: {user})")

except Exception as e:
    print(f'Error: {str(e)}', file=sys.stderr)
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to generate inventory file.${NC}"
    exit 1
fi

echo -e "\n${GREEN}Inventory file generated successfully at: $INVENTORY_FILE${NC}"

# Test SSH connectivity to all nodes
echo -e "\nTesting SSH connectivity to all nodes..."
python3 << EOF
import yaml
import subprocess
import sys

def test_ssh(host, user):
    cmd = f"ssh -i ~/.ssh/k8s_rsa -o StrictHostKeyChecking=no -o BatchMode=yes {user}@{host} 'echo SSH connection successful'"
    try:
        subprocess.run(cmd, shell=True, check=True, capture_output=True)
        return True
    except subprocess.CalledProcessError:
        return False

try:
    with open('user_input.yml', 'r') as f:
        data = yaml.safe_load(f)
    
    default_user = '$DEFAULT_USER'
    nodes = data['kubernetes_deployment']['control_plane_nodes']
    if 'worker_nodes' in data['kubernetes_deployment']:
        nodes.extend(data['kubernetes_deployment']['worker_nodes'])
    
    failed_nodes = []
    for node in nodes:
        user = node.get('ansible_user', default_user)
        print(f"\nTesting connection to {node['name']} ({node['ansible_host']}) as user '{user}'...")
        if not test_ssh(node['ansible_host'], user):
            failed_nodes.append(f"{node['name']} ({user}@{node['ansible_host']})")
    
    if failed_nodes:
        print(f"\nFailed to connect to nodes: {', '.join(failed_nodes)}", file=sys.stderr)
        sys.exit(1)
    else:
        print("\nSuccessfully connected to all nodes!")

except Exception as e:
    print(f'Error: {str(e)}', file=sys.stderr)
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}SSH connectivity test failed.${NC}"
    exit 1
fi

echo -e "\n${GREEN}SSH connectivity test passed for all nodes.${NC}"

# Run the Ansible playbook
echo -e "\nStarting Kubernetes deployment..."

# Ensure locale is set for Ansible
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

ansible-playbook kubernetes.yml -i "$INVENTORY_FILE" -vv

if [ $? -ne 0 ]; then
    echo -e "${RED}Kubernetes deployment failed.${NC}"
    exit 1
fi

echo -e "${GREEN}Kubernetes deployment completed successfully!${NC}" 