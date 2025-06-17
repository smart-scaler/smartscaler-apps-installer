#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

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

echo "Checking if Kubernetes deployment is enabled..."

# Check if kubernetes deployment is enabled
KUBERNETES_ENABLED=$(python3 -c '
import yaml
import sys
import os

try:
    with open("user_input.yml", "r") as f:
        data = yaml.safe_load(f)
        if "kubernetes_deployment" not in data:
            print("Error: kubernetes_deployment section not found in user_input.yml", file=sys.stderr)
            sys.exit(1)
        if "enabled" not in data["kubernetes_deployment"]:
            print("Error: enabled field not found in kubernetes_deployment section", file=sys.stderr)
            sys.exit(1)
        print(str(data["kubernetes_deployment"]["enabled"]).lower())
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
    echo -e "${RED}Error checking Kubernetes deployment status${NC}"
    exit 1
fi

if [ "$KUBERNETES_ENABLED" != "true" ]; then
    echo -e "${RED}Kubernetes deployment is disabled in user_input.yml. Skipping setup.${NC}"
    exit 0
fi

echo "Starting Kubernetes deployment setup..."

# Create necessary directories
mkdir -p inventory/kubespray

echo "Reading node information from user_input.yml..."

# Generate inventory from user_input.yml
python3 << EOF
import yaml
import os
import sys
from jinja2 import Template, Environment, FileSystemLoader

try:
    # Read user_input.yml
    with open('user_input.yml', 'r') as f:
        user_input = yaml.safe_load(f)
        
    if 'kubernetes_deployment' not in user_input:
        print("Error: kubernetes_deployment section not found in user_input.yml", file=sys.stderr)
        sys.exit(1)

    # Read the template
    template_path = os.path.join('templates', 'inventory.ini.j2')
    if not os.path.exists(template_path):
        print(f"Error: Template file not found at {template_path}", file=sys.stderr)
        sys.exit(1)

    # Setup Jinja2 environment
    env = Environment(loader=FileSystemLoader('templates'))
    template = env.get_template('inventory.ini.j2')

    # Process nodes to ensure they have private_ip
    def process_nodes(nodes):
        for node in nodes:
            if 'private_ip' not in node:
                print(f"Warning: private_ip not found for node {node['name']}, using ansible_host as private_ip", file=sys.stderr)
                node['private_ip'] = node['ansible_host']
        return nodes

    # Get node configurations
    control_plane_nodes = user_input['kubernetes_deployment']['control_plane_nodes']
    worker_nodes = user_input['kubernetes_deployment'].get('worker_nodes', [])

    # Process both control plane and worker nodes
    control_plane_nodes = process_nodes(control_plane_nodes)
    worker_nodes = process_nodes(worker_nodes)

    # Prepare template variables
    template_vars = {
        'control_plane_nodes': control_plane_nodes,
        'worker_nodes': worker_nodes,
        'ssh_key_path': os.path.expanduser(user_input['kubernetes_deployment']['ssh_key_path']),
        'default_ansible_user': user_input['kubernetes_deployment']['default_ansible_user'],
        'kubernetes_deployment': user_input['kubernetes_deployment']
    }

    # Write inventory file
    os.makedirs('inventory/kubespray', exist_ok=True)
    inventory_content = template.render(**template_vars)
    with open('inventory/kubespray/inventory.ini', 'w') as f:
        f.write(inventory_content)

    print("\nSuccessfully generated inventory file.")

    # Print nodes for verification
    print("\nControl Plane Nodes:")
    for node in template_vars['control_plane_nodes']:
        user = node.get('ansible_user', template_vars['default_ansible_user'])
        print(f"  - {node['name']}: Public IP: {node['ansible_host']}, Private IP: {node['private_ip']} (user: {user})")

    if template_vars['worker_nodes']:
        print("\nWorker Nodes:")
        for node in template_vars['worker_nodes']:
            user = node.get('ansible_user', template_vars['default_ansible_user'])
            print(f"  - {node['name']}: Public IP: {node['ansible_host']}, Private IP: {node['private_ip']} (user: {user})")

    # Verify and log NVIDIA configuration
    print("\nVerifying NVIDIA Configuration:")
    nvidia_config = user_input['kubernetes_deployment'].get('nvidia_runtime', {})
    if nvidia_config.get('enabled', False):
        print("✓ NVIDIA Runtime is enabled")
        print(f"  - Install Toolkit: {nvidia_config.get('install_toolkit', False)}")
        print(f"  - Architecture: {nvidia_config.get('architecture', 'amd64')}")
        print(f"  - Configure Containerd: {nvidia_config.get('configure_containerd', False)}")
        print(f"  - Create Runtime Class: {nvidia_config.get('create_runtime_class', False)}")
        
        # Verify required configurations
        missing_configs = []
        if not nvidia_config.get('install_toolkit'):
            missing_configs.append("install_toolkit should be true for NVIDIA support")
        if not nvidia_config.get('configure_containerd'):
            missing_configs.append("configure_containerd should be true for NVIDIA support")
        if missing_configs:
            print("\nWarning: Potential NVIDIA configuration issues:")
            for issue in missing_configs:
                print(f"  - {issue}")
    else:
        print("ℹ NVIDIA Runtime is disabled")

    # Verify inventory file contents
    print("\nVerifying generated inventory.ini:")
    with open('inventory/kubespray/inventory.ini', 'r') as f:
        inventory_content = f.read()
        
    if nvidia_config.get('enabled', False):
        expected_configs = [
            f'nvidia_accelerator_enabled={str(nvidia_config.get("enabled", False)).lower()}',
            f'nvidia_driver_install_container={str(nvidia_config.get("install_toolkit", False)).lower()}',
            f'nvidia_container_runtime_package_architecture="{nvidia_config.get("architecture", "amd64")}"'
        ]
        
        missing_inventory_configs = []
        for config in expected_configs:
            if config not in inventory_content:
                missing_inventory_configs.append(config)
        
        if missing_inventory_configs:
            print("\nError: Missing or incorrect NVIDIA configurations in inventory.ini:")
            print("Expected configurations:")
            for config in expected_configs:
                print(f"  - {config}")
            print("\nActual content in inventory.ini:")
            print(inventory_content)
            sys.exit(1)
        else:
            print("✓ All NVIDIA configurations properly set in inventory.ini")

    # Print complete generated inventory
    print("\n" + "="*80)
    print("Complete Generated Inventory File (inventory/kubespray/inventory.ini):")
    print("="*80)
    with open('inventory/kubespray/inventory.ini', 'r') as f:
        print(f.read())
    print("="*80 + "\n")

except FileNotFoundError as e:
    print(f"Error: File not found - {str(e)}", file=sys.stderr)
    sys.exit(1)
except yaml.YAMLError as e:
    print(f"Error parsing YAML: {str(e)}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'Error: {str(e)}', file=sys.stderr)
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to generate inventory file.${NC}"
    exit 1
fi

echo -e "\n${GREEN}Inventory file generated successfully${NC}"

# Test SSH connectivity to all nodes
echo -e "\nTesting SSH connectivity to all nodes..."
python3 << EOF
import yaml
import subprocess
import sys
import os

def test_ssh(host, user, key_path):
    expanded_key_path = os.path.expanduser(key_path)
    if not os.path.exists(expanded_key_path):
        print(f"Error: SSH key file not found at {expanded_key_path}", file=sys.stderr)
        return False
    
    cmd = f"ssh -i {expanded_key_path} -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 {user}@{host} 'echo SSH connection successful'"
    try:
        subprocess.run(cmd, shell=True, check=True, capture_output=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"SSH connection failed: {str(e)}", file=sys.stderr)
        return False

try:
    with open('user_input.yml', 'r') as f:
        data = yaml.safe_load(f)

    if 'kubernetes_deployment' not in data:
        print("Error: kubernetes_deployment section not found in user_input.yml", file=sys.stderr)
        sys.exit(1)

    kube_config = data['kubernetes_deployment']
    nodes = kube_config['control_plane_nodes']
    if 'worker_nodes' in kube_config:
        nodes.extend(kube_config['worker_nodes'])

    failed_nodes = []
    for node in nodes:
        user = node.get('ansible_user', kube_config['default_ansible_user'])
        print(f"\nTesting connection to {node['name']} ({node['ansible_host']}) as user '{user}'...")
        if not test_ssh(node['ansible_host'], user, kube_config['ssh_key_path']):
            failed_nodes.append(f"{node['name']} ({user}@{node['ansible_host']})")

    if failed_nodes:
        print(f"\nFailed to connect to nodes: {', '.join(failed_nodes)}", file=sys.stderr)
        sys.exit(1)
    else:
        print("\nSuccessfully connected to all nodes!")

except FileNotFoundError:
    print("Error: user_input.yml file not found", file=sys.stderr)
    sys.exit(1)
except yaml.YAMLError as e:
    print(f"Error parsing YAML: {str(e)}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'Error: {str(e)}', file=sys.stderr)
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}SSH connectivity test failed.${NC}"
    exit 1
fi

echo -e "\n${GREEN}SSH connectivity test passed for all nodes.${NC}"

# Check if ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}ansible-playbook command not found. Please install Ansible first.${NC}"
    exit 1
fi

# Run the Ansible playbook
echo -e "\nStarting Kubernetes deployment..."

# Ensure locale is set for Ansible
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

ansible-playbook kubernetes.yml -i inventory/kubespray/inventory.ini -e @user_input.yml -vv

if [ $? -ne 0 ]; then
    echo -e "${RED}Kubernetes deployment failed.${NC}"
    exit 1
fi

echo -e "${GREEN}Kubernetes deployment completed successfully!${NC}" 