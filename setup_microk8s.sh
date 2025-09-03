#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}MicroK8s Deployment Setup Script${NC}"
echo "======================================="

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

echo "Checking if MicroK8s deployment is enabled..."

# Check if microk8s deployment is enabled
MICROK8S_ENABLED=$(python3 -c '
import yaml
import sys
import os

try:
    with open("user_input.yml", "r") as f:
        data = yaml.safe_load(f)
        if "microk8s_deployment" not in data:
            print("Error: microk8s_deployment section not found in user_input.yml", file=sys.stderr)
            sys.exit(1)
        if "enabled" not in data["microk8s_deployment"]:
            print("Error: enabled field not found in microk8s_deployment section", file=sys.stderr)
            sys.exit(1)
        print(str(data["microk8s_deployment"]["enabled"]).lower())
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
    echo -e "${RED}Error checking MicroK8s deployment status${NC}"
    exit 1
fi

if [ "$MICROK8S_ENABLED" != "true" ]; then
    echo -e "${RED}MicroK8s deployment is disabled in user_input.yml. Skipping setup.${NC}"
    exit 0
fi

echo -e "${GREEN}MicroK8s deployment is enabled. Proceeding with setup...${NC}"

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
    echo -e "${RED}Error: kubernetes_deployment section is required for MicroK8s deployment${NC}"
    echo "MicroK8s deployment uses the same node configuration as kubespray deployment."
    exit 1
fi

# Create necessary directories
echo "Creating necessary directories..."
mkdir -p inventory/microk8s
mkdir -p output

# Ensure ansible.log file exists and is writable
touch output/ansible.log
chmod 666 output/ansible.log 2>/dev/null || echo "Note: Could not change permissions on ansible.log (this is usually fine)"

# Add a separator and timestamp to the log file
echo "" >> output/ansible.log
echo "==================================================================================" >> output/ansible.log
echo "MICROK8S DEPLOYMENT STARTED: $(date)" >> output/ansible.log
echo "==================================================================================" >> output/ansible.log
echo "" >> output/ansible.log

# Generate MicroK8s inventory and configuration
echo "Generating MicroK8s configuration files..."

python3 files/microk8s/generate_microk8s_config.py

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to generate MicroK8s configuration files${NC}"
    exit 1
fi

echo -e "${GREEN}✓ MicroK8s setup completed successfully!${NC}"

# Check if ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}ansible-playbook command not found. Please install Ansible first.${NC}"
    exit 1
fi

# Check if community.general collection is installed (required for snap module)
echo -e "\n${YELLOW}Checking Ansible collections...${NC}"
COLLECTION_CHECK=$(ansible-galaxy collection list community.general 2>/dev/null | grep community.general || echo "not found")
if [[ "$COLLECTION_CHECK" == "not found" ]]; then
    echo -e "${YELLOW}Installing required Ansible collection: community.general${NC}"
    ansible-galaxy collection install community.general
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install community.general collection${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ community.general collection is available${NC}"
fi

# Test SSH connectivity to all nodes
echo -e "\n${YELLOW}Testing SSH connectivity to all nodes...${NC}"
python3 files/microk8s/test_ssh_connectivity.py

if [ $? -ne 0 ]; then
    echo -e "${RED}SSH connectivity test failed.${NC}"
    exit 1
fi

echo -e "\n${GREEN}SSH connectivity test passed for all nodes.${NC}"

# Jetson prerequisites will be executed automatically during MicroK8s deployment
echo -e "\n${YELLOW}🔧 Jetson prerequisites will be executed on all nodes during MicroK8s deployment${NC}"
echo -e "${YELLOW}This ensures Jetson devices are detected and configured before cluster setup${NC}"

# Log Jetson role execution plan
echo "JETSON ROLE EXECUTION PLAN:" >> output/ansible.log
echo "============================" >> output/ansible.log
echo "Role: jetson_prerequisites" >> output/ansible.log
echo "Target: ALL nodes in inventory" >> output/ansible.log
echo "Execution: During MicroK8s deployment (first play)" >> output/ansible.log
echo "Configuration: From user_input.yml jetson_prerequisites section" >> output/ansible.log
echo "" >> output/ansible.log

# Ensure our custom Jetson role is available in microk8s-ansible
echo -e "\n${YELLOW}Ensuring custom Jetson role is available...${NC}"
if [ ! -d "microk8s-ansible/roles/jetson_prerequisites" ]; then
    echo -e "${YELLOW}Copying Jetson role to microk8s-ansible...${NC}"
    cp -r roles/jetson_prerequisites microk8s-ansible/roles/
    echo -e "${GREEN}✓ Jetson role copied to microk8s-ansible${NC}"
else
    echo -e "${GREEN}✓ Jetson role already present in microk8s-ansible${NC}"
fi

# Ensure our custom NVIDIA role is available in microk8s-ansible
echo -e "\n${YELLOW}Ensuring custom NVIDIA role is available...${NC}"
if [ ! -d "microk8s-ansible/roles/nvidia_prerequisites" ]; then
    echo -e "${YELLOW}Copying NVIDIA role to microk8s-ansible...${NC}"
    cp -r roles/nvidia_prerequisites microk8s-ansible/roles/
    echo -e "${GREEN}✓ NVIDIA role copied to microk8s-ansible${NC}"
else
    echo -e "${GREEN}✓ NVIDIA role already present in microk8s-ansible${NC}"
fi

# Verify Jetson role configuration before execution
echo -e "\n${YELLOW}🔍 Pre-execution Jetson role verification...${NC}"

# Check if Jetson prerequisites are enabled in user_input.yml
JETSON_ENABLED=$(python3 -c "
import yaml
with open('user_input.yml', 'r') as f:
    data = yaml.safe_load(f)
print(data.get('jetson_prerequisites', {}).get('enabled', False))
" 2>/dev/null || echo "false")

if [ "$JETSON_ENABLED" = "True" ]; then
    echo -e "${GREEN}✓ Jetson prerequisites enabled in user_input.yml${NC}"
    echo "✓ Jetson prerequisites enabled in user_input.yml" >> output/ansible.log
else
    echo -e "${YELLOW}⚠️  Jetson prerequisites not enabled in user_input.yml${NC}"
    echo "⚠️  Jetson prerequisites not enabled in user_input.yml" >> output/ansible.log
fi

# Check if NVIDIA prerequisites are enabled in user_input.yml
NVIDIA_ENABLED=$(python3 -c "
import yaml
with open('user_input.yml', 'r') as f:
    data = yaml.safe_load(f)
print(data.get('nvidia_prerequisites', {}).get('enabled', False))
" 2>/dev/null || echo "false")

if [ "$NVIDIA_ENABLED" = "True" ]; then
    echo -e "${GREEN}✓ NVIDIA prerequisites enabled in user_input.yml${NC}"
    echo "✓ NVIDIA prerequisites enabled in user_input.yml" >> output/ansible.log
else
    echo -e "${YELLOW}⚠️  NVIDIA prerequisites not enabled in user_input.yml${NC}"
    echo "⚠️  NVIDIA prerequisites not enabled in user_input.yml" >> output/ansible.log
fi

# Verify Jetson role files exist
if [ -d "roles/jetson_prerequisites" ]; then
    echo -e "${GREEN}✓ Jetson role directory exists${NC}"
    echo "✓ Jetson role directory exists" >> output/ansible.log
    
    # Check key role files
    if [ -f "roles/jetson_prerequisites/tasks/main.yml" ]; then
        echo -e "${GREEN}✓ Jetson role tasks file exists${NC}"
        echo "✓ Jetson role tasks file exists" >> output/ansible.log
    else
        echo -e "${RED}✗ Jetson role tasks file missing${NC}"
        echo "✗ Jetson role tasks file missing" >> output/ansible.log
    fi
    
    if [ -f "roles/jetson_prerequisites/defaults/main.yml" ]; then
        echo -e "${GREEN}✓ Jetson role defaults file exists${NC}"
        echo "✓ Jetson role defaults file exists" >> output/ansible.log
    else
        echo -e "${RED}✗ Jetson role defaults file missing${NC}"
        echo "✗ Jetson role defaults file missing" >> output/ansible.log
    fi
else
    echo -e "${RED}✗ Jetson role directory missing${NC}"
    echo "✗ Jetson role directory missing" >> output/ansible.log
fi

# Run the Ansible playbook
echo -e "\nStarting MicroK8s deployment..."
echo -e "${YELLOW}Using generated MicroK8s configuration:${NC}"
echo "  - Inventory: inventory/microk8s/inventory.yml"
echo "  - Group Variables: inventory/microk8s/group_vars/all.yml"
echo ""

# Ensure locale is set for Ansible
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

# Run from microk8s-ansible directory to ensure roles are found
echo -e "\n${YELLOW}Starting MicroK8s deployment with Ansible...${NC}"
echo -e "Logs will be written to: ${GREEN}output/ansible.log${NC}"
echo ""

cd microk8s-ansible
# Use the main ansible.cfg to ensure proper logging
export ANSIBLE_CONFIG=../ansible.cfg
ansible-playbook site.yml \
    -i ../inventory/microk8s/inventory.yml \
    -e @../user_input.yml \
    --become \
    --become-user=root \
    -vvv

# Return to original directory
cd ..

if [ $? -ne 0 ]; then
    echo -e "${RED}MicroK8s deployment failed.${NC}"
    # Add failure marker to log
    echo "MICROK8S DEPLOYMENT FAILED: $(date)" >> output/ansible.log
    exit 1
fi

# Verify Jetson role execution
echo -e "\n${YELLOW}🔍 Verifying Jetson role execution...${NC}"
echo "JETSON ROLE EXECUTION VERIFICATION:" >> output/ansible.log
echo "===================================" >> output/ansible.log

# Check if Jetson role execution is in the logs
if grep -q "jetson_prerequisites" output/ansible.log; then
    echo -e "${GREEN}✓ Jetson role execution found in logs${NC}"
    echo "✓ Jetson role execution found in logs" >> output/ansible.log
    
    # Count Jetson role task executions
    JETSON_TASKS=$(grep -c "jetson_prerequisites.*TASK" output/ansible.log || echo "0")
    echo -e "${GREEN}✓ Jetson role executed with ${JETSON_TASKS} tasks${NC}"
    echo "✓ Jetson role executed with ${JETSON_TASKS} tasks" >> output/ansible.log
    
    # Check for Jetson detection results
    if grep -q "Jetson Detection Results" output/ansible.log; then
        echo -e "${GREEN}✓ Jetson detection completed successfully${NC}"
        echo "✓ Jetson detection completed successfully" >> output/ansible.log
    else
        echo -e "${YELLOW}⚠️  Jetson detection results not found in logs${NC}"
        echo "⚠️  Jetson detection results not found in logs" >> output/ansible.log
    fi
else
    echo -e "${RED}✗ Jetson role execution not found in logs${NC}"
    echo "✗ Jetson role execution not found in logs" >> output/ansible.log
    echo -e "${YELLOW}⚠️  This may indicate the Jetson role did not run properly${NC}"
fi

# Verify NVIDIA role execution
echo -e "\n${YELLOW}🔍 Verifying NVIDIA role execution...${NC}"
echo "NVIDIA ROLE EXECUTION VERIFICATION:" >> output/ansible.log
echo "===================================" >> output/ansible.log

# Check if NVIDIA role execution is in the logs
if grep -q "nvidia_prerequisites" output/ansible.log; then
    echo -e "${GREEN}✓ NVIDIA role execution found in logs${NC}"
    echo "✓ NVIDIA role execution found in logs" >> output/ansible.log
    
    # Count NVIDIA role task executions
    NVIDIA_TASKS=$(grep -c "nvidia_prerequisites.*TASK" output/ansible.log || echo "0")
    echo -e "${GREEN}✓ NVIDIA role executed with ${NVIDIA_TASKS} tasks${NC}"
    echo "✓ NVIDIA role executed with ${NVIDIA_TASKS} tasks" >> output/ansible.log
    
    # Check for NVIDIA detection results
    if grep -q "NVIDIA GPU Detection Results" output/ansible.log; then
        echo -e "${GREEN}✓ NVIDIA detection completed successfully${NC}"
        echo "✓ NVIDIA detection completed successfully" >> output/ansible.log
    else
        echo -e "${YELLOW}⚠️  NVIDIA detection results not found in logs${NC}"
        echo "⚠️  NVIDIA detection results not found in logs" >> output/ansible.log
    fi
else
    echo -e "${RED}✗ NVIDIA role execution not found in logs${NC}"
    echo "✗ NVIDIA role execution not found in logs" >> output/ansible.log
    echo -e "${YELLOW}⚠️  This may indicate the NVIDIA role did not run properly${NC}"
fi

# Add completion marker to log
echo "MICROK8S DEPLOYMENT COMPLETED SUCCESSFULLY: $(date)" >> output/ansible.log
echo "JETSON ROLE VERIFICATION COMPLETED: $(date)" >> output/ansible.log
echo "NVIDIA ROLE VERIFICATION COMPLETED: $(date)" >> output/ansible.log

echo -e "${GREEN}MicroK8s deployment completed successfully!${NC}"
echo -e "Kubeconfig file available at: ${GREEN}output/kubeconfig${NC}"

# MicroK8s verification functions
verify_microk8s_cluster() {
    local kubeconfig="$1"
    local max_attempts=30
    local attempt=1
    
    echo -e "\n${YELLOW}🔍 Starting MicroK8s cluster verification...${NC}"
    
    # Wait for cluster to be ready
    echo -e "${YELLOW}⏳ Waiting for cluster to be ready (max ${max_attempts} attempts)...${NC}"
    while [ $attempt -le $max_attempts ]; do
        if KUBECONFIG="$kubeconfig" kubectl get nodes --request-timeout=10s >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Cluster is responding (attempt ${attempt}/${max_attempts})${NC}"
            break
        else
            echo -e "${YELLOW}⏳ Cluster not ready yet (attempt ${attempt}/${max_attempts})...${NC}"
            sleep 10
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        echo -e "${RED}✗ Cluster verification timeout after ${max_attempts} attempts${NC}"
        return 1
    fi
    
    # Verify cluster info
    echo -e "\n${YELLOW}📋 Cluster Information:${NC}"
    if KUBECONFIG="$kubeconfig" kubectl cluster-info --request-timeout=10s; then
        echo -e "${GREEN}✓ Cluster info retrieved successfully${NC}"
    else
        echo -e "${RED}✗ Failed to get cluster info${NC}"
        return 1
    fi
    
    # Check nodes
    echo -e "\n${YELLOW}🖥️  Node Status:${NC}"
    if KUBECONFIG="$kubeconfig" kubectl get nodes --request-timeout=10s; then
        echo -e "${GREEN}✓ Node information retrieved successfully${NC}"
    else
        echo -e "${RED}✗ Failed to get node information${NC}"
        return 1
    fi
    
    # Check system pods
    echo -e "\n${YELLOW}🔧 System Pods Status:${NC}"
    if KUBECONFIG="$kubeconfig" kubectl get pods -n kube-system --request-timeout=10s; then
        echo -e "${GREEN}✓ System pods information retrieved successfully${NC}"
    else
        echo -e "${RED}✗ Failed to get system pods information${NC}"
        return 1
    fi
    
    # Check MicroK8s add-ons
    echo -e "\n${YELLOW}🔌 MicroK8s Add-ons Status:${NC}"
    local critical_addons=("dns" "storage" "ingress")
    local all_ready=true
    
    for addon in "${critical_addons[@]}"; do
        local addon_status=$(KUBECONFIG="$kubeconfig" kubectl get pods -n kube-system --request-timeout=10s -l "k8s-app=${addon}" -o jsonpath='{.items[*].status.phase}' 2>/dev/null)
        if [[ "$addon_status" == *"Running"* ]]; then
            echo -e "${GREEN}✓ ${addon} add-on is Running${NC}"
        else
            echo -e "${YELLOW}⚠️  ${addon} add-on status: ${addon_status}${NC}"
        fi
    done
    
    # Overall status
    echo -e "\n${GREEN}🎉 MicroK8s cluster verification completed successfully!${NC}"
    return 0
}

# Run verification if kubeconfig exists
if [ -f "output/kubeconfig" ]; then
    echo -e "\n${YELLOW}🔍 Running MicroK8s cluster verification...${NC}"
    if verify_microk8s_cluster "output/kubeconfig"; then
        echo -e "${GREEN}✓ MicroK8s cluster verification passed${NC}"
    else
        echo -e "${YELLOW}⚠️  MicroK8s cluster verification completed with issues${NC}"
        echo -e "${YELLOW}Please check the cluster manually:${NC}"
        echo -e "  export KUBECONFIG=\$PWD/output/kubeconfig"
        echo -e "  kubectl get nodes"
        echo -e "  kubectl get pods -n kube-system"
    fi
else
    echo -e "\n${YELLOW}⚠️  Skipping cluster verification - kubeconfig not found${NC}"
fi

echo ""
echo -e "${YELLOW}Cluster Information:${NC}"
echo "  - Cluster Name: smart-scaler-microk8s-$(python3 -c "
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
"):16443"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Export kubeconfig: export KUBECONFIG=\$PWD/output/kubeconfig"
echo "2. Verify cluster: kubectl get nodes"
echo "3. Check system pods: kubectl get pods -n kube-system"
echo "4. Test cluster access: kubectl cluster-info"
echo "5. Check MicroK8s status: microk8s status (on remote nodes)"
echo ""
echo -e "${GREEN}Configuration files generated:${NC}"
echo "  - inventory/microk8s/inventory.yml"
echo "  - inventory/microk8s/group_vars/all.yml"
echo ""
echo -e "${GREEN}Logs written to:${NC}"
echo "  - output/ansible.log (Ansible execution logs)"
echo ""
echo -e "${YELLOW}Note:${NC} MicroK8s deployment uses the same node configuration as kubespray deployment"
echo "from the kubernetes_deployment section in user_input.yml"
