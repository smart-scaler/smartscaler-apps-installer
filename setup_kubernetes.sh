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
# python3 -c "
# import sys
# import subprocess
# 
# required_packages = ['pyyaml', 'jinja2']
# installed_packages = subprocess.check_output([sys.executable, '-m', 'pip', 'freeze']).decode().split('\n')
# installed_packages = [pkg.split('==')[0].lower() for pkg in installed_packages if pkg]
# 
# missing_packages = [pkg for pkg in required_packages if pkg.lower() not in installed_packages]
# 
# if missing_packages:
#     print(f'Installing missing packages: {missing_packages}')
#     for package in missing_packages:
#         subprocess.check_call([sys.executable, '-m', 'pip', 'install', package])
# else:
#     print('All required packages are installed.')
# "
echo "Skipping package installation - assuming packages are available"

# if [ $? -ne 0 ]; then
#     echo -e "${RED}Failed to install required Python packages${NC}"
#     exit 1
# fi

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

# Create necessary directories with proper permissions
mkdir -p inventory/kubespray
mkdir -p output
chmod 755 output
touch output/ansible.log
chmod 666 output/ansible.log

echo "Reading node information from user_input.yml..."

# Generate inventory from user_input.yml
python3 << EOF
import yaml
import os
import sys
from jinja2 import Template, Environment, FileSystemLoader

def get_venv_python():
    """Get the Python interpreter path from the virtual environment."""
    return '/usr/bin/python3'  # Use system Python as default

try:
    # Read user_input.yml
    with open('user_input.yml', 'r') as f:
        user_input = yaml.safe_load(f)
        
    if 'kubernetes_deployment' not in user_input:
        print("Error: kubernetes_deployment section not found in user_input.yml", file=sys.stderr)
        sys.exit(1)

    kubernetes_deployment = user_input['kubernetes_deployment']

    # Use configured Python interpreter or default
    if 'python_config' not in kubernetes_deployment:
        kubernetes_deployment['python_config'] = {
            'interpreter_path': '/usr/bin/python3'  # Use configured path
        }
    
    # Ensure the interpreter path is what we configured
    if kubernetes_deployment['python_config']['interpreter_path'] == '/home/nvidia/smartscaler-apps-installer/venv/bin/python3':
        print("Warning: Overriding hardcoded Python interpreter path with system Python")
        kubernetes_deployment['python_config']['interpreter_path'] = '/usr/bin/python3'

    # Ensure network configuration exists with defaults
    if 'network_config' not in kubernetes_deployment:
        kubernetes_deployment['network_config'] = {
            'service_subnet': '10.233.0.0/18',
            'pod_subnet': '10.233.64.0/18',
            'node_prefix': 24
        }

    # Process nodes to ensure they have all required configurations
    def process_nodes(nodes):
        processed = []
        for node in nodes:
            if not isinstance(node, dict):
                print(f"Error: Invalid node configuration: {node}", file=sys.stderr)
                sys.exit(1)
                
            if 'name' not in node or 'ansible_host' not in node:
                print(f"Error: Node missing required fields (name and ansible_host): {node}", file=sys.stderr)
                sys.exit(1)

            # Ensure private_ip exists
            if 'private_ip' not in node:
                print(f"Warning: private_ip not found for node {node['name']}, using ansible_host as private_ip", file=sys.stderr)
                node['private_ip'] = node['ansible_host']

            # Set Python interpreter for the node if not set
            if 'ansible_python_interpreter' not in node:
                node['ansible_python_interpreter'] = kubernetes_deployment['python_config']['interpreter_path']

            processed.append(node)
        return processed

    # Get and process node configurations
    control_plane_nodes = process_nodes(kubernetes_deployment.get('control_plane_nodes', []))
    worker_nodes = process_nodes(kubernetes_deployment.get('worker_nodes', []))

    # Validate API server configuration
    api_server = kubernetes_deployment.get('api_server', {})
    if not api_server.get('host'):
        print("Error: API server host must be specified in kubernetes_deployment.api_server", file=sys.stderr)
        sys.exit(1)
    if not api_server.get('port'):
        api_server['port'] = 6443
        print(f"Warning: API server port not specified, using default: {api_server['port']}")

    # Prepare template variables
    template_vars = {
        'control_plane_nodes': control_plane_nodes,
        'worker_nodes': worker_nodes,
        'ssh_key_path': os.path.expanduser(kubernetes_deployment.get('ssh_key_path', '~/.ssh/id_rsa')),
        'default_ansible_user': kubernetes_deployment.get('default_ansible_user', 'root'),
        'kubernetes_deployment': kubernetes_deployment
    }

    # Setup Jinja2 environment and render template
    env = Environment(loader=FileSystemLoader('templates'))
    template = env.get_template('inventory.ini.j2')
    
    # Write inventory file
    os.makedirs('inventory/kubespray', exist_ok=True)
    inventory_content = template.render(**template_vars)
    with open('inventory/kubespray/inventory.ini', 'w') as f:
        f.write(inventory_content)

    print("\nSuccessfully generated inventory file.")
    
    # Print the generated inventory content
    print("\nGenerated inventory.ini content:")
    print("=" * 50)
    with open('inventory/kubespray/inventory.ini', 'r') as f:
        print(f.read())
    print("=" * 50)

    # Print configuration summary
    print("\nConfiguration Summary:")
    print(f"Python Interpreter: {kubernetes_deployment['python_config']['interpreter_path']}")
    print(f"API Server: {api_server['host']}:{api_server['port']}")
    print(f"Network Plugin: {kubernetes_deployment.get('network_plugin', 'calico')}")
    print(f"Container Runtime: {kubernetes_deployment.get('container_runtime', 'containerd')}")
    print(f"DNS Mode: {kubernetes_deployment.get('dns_mode', 'coredns')}")
    
    print("\nControl Plane Nodes:")
    for node in control_plane_nodes:
        print(f"  - {node['name']}: {node['ansible_host']} (Private IP: {node['private_ip']})")
        print(f"    Python Interpreter: {node.get('ansible_python_interpreter', kubernetes_deployment['python_config']['interpreter_path'])}")
    
    if worker_nodes:
        print("\nWorker Nodes:")
        for node in worker_nodes:
            print(f"  - {node['name']}: {node['ansible_host']} (Private IP: {node['private_ip']})")
            print(f"    Python Interpreter: {node.get('ansible_python_interpreter', kubernetes_deployment['python_config']['interpreter_path'])}")

except Exception as e:
    print(f"Error: {str(e)}", file=sys.stderr)
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to generate inventory file${NC}"
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

# Get Python interpreter path from the inventory
PYTHON_INTERPRETER=$(grep "ansible_python_interpreter" inventory/kubespray/inventory.ini | cut -d'=' -f2)

# Run ansible-playbook with the correct Python interpreter
ANSIBLE_PYTHON_INTERPRETER="$PYTHON_INTERPRETER" ansible-playbook kubernetes.yml -i inventory/kubespray/inventory.ini -vvv

if [ $? -ne 0 ]; then
    echo -e "${RED}Kubernetes deployment failed.${NC}"
    exit 1
fi

echo -e "${GREEN}Kubernetes deployment completed successfully!${NC}" 