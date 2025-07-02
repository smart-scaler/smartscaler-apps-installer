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

    # Generate Kubespray group_vars from user_input.yml
    print("\nGenerating Kubespray group variables...")
    
    # Load group_vars template
    try:
        with open('templates/kubespray_group_vars_all.yml.j2', 'r') as f:
            group_vars_template = Template(f.read())
    except FileNotFoundError:
        print("Error: Group vars template file not found at templates/kubespray_group_vars_all.yml.j2")
        sys.exit(1)
    
    # Create group_vars directory structure
    os.makedirs('inventory/kubespray/group_vars/all', exist_ok=True)
    os.makedirs('inventory/kubespray/group_vars/kube_control_plane', exist_ok=True)
    os.makedirs('inventory/kubespray/group_vars/kube_node', exist_ok=True)
    os.makedirs('inventory/kubespray/group_vars/etcd', exist_ok=True)
    
    # Render group_vars/all/all.yml
    group_vars_content = group_vars_template.render(**template_vars)
    with open('inventory/kubespray/group_vars/all/all.yml', 'w') as f:
        f.write(group_vars_content)
    
    print("✓ Generated group_vars/all/all.yml")
    
    # Generate k8s-cluster.yml with certificate SAN configuration
    print("Generating k8s-cluster configuration with certificate SAN fix...")
    
    try:
        with open('templates/kubespray_k8s_cluster.yml.j2', 'r') as f:
            k8s_cluster_template = Template(f.read())
    except FileNotFoundError:
        print("Error: K8s cluster template file not found at templates/kubespray_k8s_cluster.yml.j2")
        sys.exit(1)
    
    # Create k8s_cluster group_vars directory
    os.makedirs('inventory/kubespray/group_vars/k8s_cluster', exist_ok=True)
    
    # Render group_vars/k8s_cluster/k8s-cluster.yml with certificate SAN fix
    k8s_cluster_content = k8s_cluster_template.render(**template_vars)
    with open('inventory/kubespray/group_vars/k8s_cluster/k8s-cluster.yml', 'w') as f:
        f.write(k8s_cluster_content)
    
    print("✓ Generated group_vars/k8s_cluster/k8s-cluster.yml with certificate SAN fix")
    print("  - Certificate will include 0.0.0.0 to fix 'x509: certificate is valid for ... not 0.0.0.0' error")
    
    # Validate multi-master configuration
    num_control_plane = len(template_vars['control_plane_nodes'])
    lb_config = user_input['kubernetes_deployment'].get('load_balancer', {})
    
    if num_control_plane > 1:
        print(f"\n🔧 Multi-Master HA Configuration Detected ({num_control_plane} control plane nodes)")
        
        if not lb_config.get('enabled', False):
            print("⚠️  WARNING: Load balancer is disabled but you have multiple control plane nodes.")
            print("   This configuration may cause connectivity issues.")
            print("   Consider enabling load_balancer.enabled: true in user_input.yml")
        else:
            lb_type = lb_config.get('type', 'localhost')
            print(f"✓ Load balancer enabled: {lb_type}")
            
            if lb_type == "localhost" and lb_config.get('localhost', {}).get('enabled', False):
                lb_impl = lb_config['localhost'].get('lb_type', 'nginx')
                print(f"  - Using {lb_impl} for local load balancing")
            elif lb_type == "external" and lb_config.get('external', {}).get('enabled', False):
                ext_addr = lb_config['external'].get('address', 'NOT_SET')
                print(f"  - Using external load balancer: {ext_addr}")
            elif lb_type == "kube-vip" and lb_config.get('kube_vip', {}).get('enabled', False):
                vip_addr = lb_config['kube_vip'].get('vip_address', 'NOT_SET')
                print(f"  - Using kube-vip with VIP: {vip_addr}")
                
        # Validate etcd HA configuration
        etcd_config = user_input['kubernetes_deployment'].get('etcd_ha', {})
        if etcd_config.get('enabled', False):
            print("✓ etcd HA configuration enabled")
            if etcd_config.get('events_cluster', {}).get('enabled', False):
                print("  - Events cluster separation enabled")
        else:
            print("⚠️  WARNING: etcd HA is disabled for multi-master setup.")
            print("   Consider enabling etcd_ha.enabled: true for production deployments.")
            
    elif num_control_plane == 1:
        print(f"\n🔧 Single Master Configuration")
        if lb_config.get('enabled', False):
            print("ℹ️  Load balancer is enabled but not needed for single master setup.")
    else:
        print("\n❌ ERROR: No control plane nodes configured!")
        sys.exit(1)

    print("\nSuccessfully generated Kubespray configuration files.")

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
    print("="*80)
    
    # Print generated group_vars for verification
    print("\n" + "="*80)
    print("Generated Kubespray Group Variables (inventory/kubespray/group_vars/all/all.yml):")
    print("="*80)
    with open('inventory/kubespray/group_vars/all/all.yml', 'r') as f:
        group_vars_content = f.read()
        print(group_vars_content)
    print("="*80)
    
    # Validate critical configurations in group_vars
    print("\n🔍 Validating Generated Configuration:")
    critical_checks = []
    
    if num_control_plane > 1:
        if 'loadbalancer_apiserver_localhost: true' in group_vars_content:
            critical_checks.append("✓ Local load balancer configured")
        elif 'loadbalancer_apiserver:' in group_vars_content:
            critical_checks.append("✓ External load balancer configured")
        elif 'kube_vip_controlplane_enabled: true' in group_vars_content:
            critical_checks.append("✓ kube-vip load balancer configured")
        else:
            critical_checks.append("❌ No load balancer configured for multi-master setup")
    
    if 'nvidia_accelerator_enabled: true' in group_vars_content:
        critical_checks.append("✓ NVIDIA GPU support enabled")
    
    if 'etcd_events_cluster_enabled: true' in group_vars_content:
        critical_checks.append("✓ etcd events cluster separation enabled")
    
    if 'rbac_enabled: true' in group_vars_content:
        critical_checks.append("✓ RBAC security enabled")
    
    for check in critical_checks:
        print(f"  {check}")
    
    print("\n")

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
echo -e "${YELLOW}Certificate SAN fix applied: 0.0.0.0 included in k8s-cluster.yml${NC}"

# Ensure locale is set for Ansible
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

# Use kubernetes.yml playbook which provides better orchestration
if [ ! -f "kubernetes.yml" ]; then
    echo -e "${RED}Error: kubernetes.yml not found in the current directory.${NC}"
    exit 1
fi

# Run Kubespray deployment with generated inventory and group_vars
echo "Using generated Kubespray configuration:"
echo "  - Inventory: inventory/kubespray/inventory.ini"
echo "  - Group Variables: inventory/kubespray/group_vars/all/all.yml"
echo ""

ansible-playbook kubernetes.yml \
    -i inventory/kubespray/inventory.ini \
    -e @user_input.yml \
    --become \
    --become-user=root \
    -vvv

if [ $? -ne 0 ]; then
    echo -e "${RED}Kubernetes deployment failed.${NC}"
    exit 1
fi

echo -e "${GREEN}Kubernetes deployment completed successfully!${NC}"
echo -e "Kubeconfig file will be available at: ${GREEN}output/kubeconfig${NC} after kubernetes.yml completes" 