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
chmod 666 output/ansible.log 2>/dev/null || echo "Note: Could not change permissions on ansible.log (this is usually fine)"

# Add a separator and timestamp to the log file
echo "" >> output/ansible.log
echo "==================================================================================" >> output/ansible.log
echo "K3S DEPLOYMENT STARTED: $(date)" >> output/ansible.log
echo "==================================================================================" >> output/ansible.log
echo "" >> output/ansible.log

# Check if k3s-ansible directory exists, use local copy only
# NOTE: This script maintains a local copy of k3s-ansible without git tracking
# to preserve customizations and prevent accidental updates
if [ ! -d "k3s-ansible" ]; then
    echo -e "${RED}ERROR: k3s-ansible directory not found!${NC}"
    echo -e "${YELLOW}This directory should contain the local copy of k3s-ansible${NC}"
    echo -e "${YELLOW}Please ensure the k3s-ansible directory is present in your workspace${NC}"
    echo -e "${YELLOW}Do NOT clone from GitHub - always use the local copy${NC}"
    exit 1
fi
else
    echo -e "${GREEN}✓ Using existing local k3s-ansible copy${NC}"
    echo -e "${YELLOW}ℹ️  Using local copy (no git tracking)${NC}"
    
    # Verify local copy is functional
    if [ ! -f "k3s-ansible/playbooks/site.yml" ]; then
        echo -e "${RED}Local k3s-ansible copy appears corrupted or incomplete${NC}"
        echo -e "${YELLOW}Please ensure the k3s-ansible directory contains all required files${NC}"
        echo -e "${YELLOW}Do NOT clone from GitHub - always use the local copy${NC}"
        exit 1
    fi
    
    # Check if our custom Jetson role is present
    if [ ! -d "k3s-ansible/roles/jetson_prerequisites" ]; then
        echo -e "${YELLOW}⚠️  Custom Jetson role not found in local copy${NC}"
        echo -e "${YELLOW}   This role will be copied from parent directory${NC}"
    else
        echo -e "${GREEN}✓ Custom Jetson role found in local copy${NC}"
    fi
fi

# Generate K3s inventory and configuration
echo "Generating K3s configuration files..."

python3 files/k3s/generate_k3s_config.py

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
python3 files/k3s/test_ssh_connectivity.py

if [ $? -ne 0 ]; then
    echo -e "${RED}SSH connectivity test failed.${NC}"
    exit 1
fi

echo -e "\n${GREEN}SSH connectivity test passed for all nodes.${NC}"

# Jetson prerequisites will be executed automatically during K3s deployment
echo -e "\n${YELLOW}🔧 Jetson prerequisites will be executed on all nodes during K3s deployment${NC}"
echo -e "${YELLOW}This ensures Jetson devices are detected and configured before cluster setup${NC}"

# Log Jetson role execution plan
echo "JETSON ROLE EXECUTION PLAN:" >> output/ansible.log
echo "============================" >> output/ansible.log
echo "Role: jetson_prerequisites" >> output/ansible.log
echo "Target: ALL nodes in inventory" >> output/ansible.log
echo "Execution: During K3s deployment (first play)" >> output/ansible.log
echo "Configuration: From user_input.yml jetson_prerequisites section" >> output/ansible.log
echo "" >> output/ansible.log

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

# Ensure our custom Jetson role is available in k3s-ansible
echo -e "\n${YELLOW}Ensuring custom Jetson role is available...${NC}"
if [ ! -d "k3s-ansible/roles/jetson_prerequisites" ]; then
    echo -e "${YELLOW}Copying Jetson role to k3s-ansible...${NC}"
    cp -r roles/jetson_prerequisites k3s-ansible/roles/
    echo -e "${GREEN}✓ Jetson role copied to k3s-ansible${NC}"
else
    echo -e "${GREEN}✓ Jetson role already present in k3s-ansible${NC}"
fi

# Ensure our custom NVIDIA role is available in k3s-ansible
echo -e "\n${YELLOW}Ensuring custom NVIDIA role is available...${NC}"
if [ ! -d "k3s-ansible/roles/nvidia_prerequisites" ]; then
    echo -e "${YELLOW}Copying NVIDIA role to k3s-ansible...${NC}"
    cp -r roles/nvidia_prerequisites k3s-ansible/roles/
    echo -e "${GREEN}✓ NVIDIA role copied to k3s-ansible${NC}"
else
    echo -e "${GREEN}✓ NVIDIA role already present in k3s-ansible${NC}"
fi

# Ensure output directory exists
mkdir -p output

# Run K3s deployment with generated inventory and group_vars using local k3s-ansible
# Copy our generated inventory to k3s-ansible directory
cp inventory/k3s/inventory.yml k3s-ansible/
cp -r inventory/k3s/group_vars k3s-ansible/

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
    
    # Check for jtop.sock verification
    if grep -q "jtop.sock Status" output/ansible.log; then
        echo -e "${GREEN}✓ jtop.sock verification completed${NC}"
        echo "✓ jtop.sock verification completed" >> output/ansible.log
    else
        echo -e "${YELLOW}⚠️  jtop.sock verification not found in logs${NC}"
        echo "⚠️  jtop.sock verification not found in logs" >> output/ansible.log
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
         
         # Check for NVIDIA installation verification
         if grep -q "NVIDIA Installation Verification" output/ansible.log; then
             echo -e "${GREEN}✓ NVIDIA installation verification completed${NC}"
             echo "✓ NVIDIA installation verification completed" >> output/ansible.log
         else
             echo -e "${YELLOW}⚠️  NVIDIA installation verification not found in logs${NC}"
             echo "⚠️  NVIDIA installation verification not found in logs" >> output/ansible.log
         fi
         
     else
         echo -e "${RED}✗ NVIDIA role execution not found in logs${NC}"
         echo "✗ NVIDIA role execution not found in logs" >> output/ansible.log
         echo -e "${YELLOW}⚠️  This may indicate the NVIDIA role did not run properly${NC}"
     fi
     
     # Add completion marker to log
     echo "K3S DEPLOYMENT COMPLETED SUCCESSFULLY: $(date)" >> output/ansible.log
     echo "JETSON ROLE VERIFICATION COMPLETED: $(date)" >> output/ansible.log
     echo "NVIDIA ROLE VERIFICATION COMPLETED: $(date)" >> output/ansible.log

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
if scp -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}:/etc/rancher/k3s/k3s.yaml" "output/kubeconfig" 2>/dev/null; then
    echo -e "${GREEN}✓ Kubeconfig copied from /etc/rancher/k3s/k3s.yaml${NC}"
    
    # Fix the kubeconfig IP address (replace 127.0.0.1 with actual server IP)
    echo -e "\n${YELLOW}Fixing kubeconfig IP address...${NC}"
    if grep -q "127.0.0.1" output/kubeconfig; then
        # Replace 127.0.0.1 with actual IP
        sed -i "s/127.0.0.1/${CONTROL_PLANE_IP}/g" output/kubeconfig
        echo -e "${GREEN}✓ Updated kubeconfig IP from 127.0.0.1 to ${CONTROL_PLANE_IP}${NC}"
    else
        echo -e "${GREEN}✓ Kubeconfig IP is already correct${NC}"
    fi
elif scp -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}:~/.kube/config" "output/kubeconfig" 2>/dev/null; then
    echo -e "${GREEN}✓ Kubeconfig copied from ~/.kube/config${NC}"
    
    # Fix the kubeconfig IP address if needed
    echo -e "\n${YELLOW}Fixing kubeconfig IP address...${NC}"
    if grep -q "127.0.0.1" output/kubeconfig; then
        sed -i "s/127.0.0.1/${CONTROL_PLANE_IP}/g" output/kubeconfig
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
    echo -e "  scp -i ${SSH_KEY_PATH} ${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}:<path> output/kubeconfig"
    echo -e "${YELLOW}Please check:${NC}"
    echo -e "  1. SSH key permissions and path"
    echo -e "  2. Remote node connectivity"
    echo -e "  3. K3s installation status on remote node"
fi

echo -e "${GREEN}K3s deployment completed successfully!${NC}"
echo -e "Kubeconfig file will be available at: ${GREEN}output/kubeconfig${NC}"

# K3s verification functions
verify_k3s_cluster() {
    local kubeconfig="$1"
    local max_attempts=30
    local attempt=1
    
    echo -e "\n${YELLOW}🔍 Starting Kubernetes cluster verification...${NC}"
    
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
    
    # Check node readiness
    echo -e "\n${YELLOW}✅ Node Readiness Check:${NC}"
    local ready_nodes=$(KUBECONFIG="$kubeconfig" kubectl get nodes --request-timeout=10s -o jsonpath='{.items[?(@.status.conditions[?(@.type=="Ready")].status=="True")].metadata.name}' 2>/dev/null | wc -w)
    local total_nodes=$(KUBECONFIG="$kubeconfig" kubectl get nodes --request-timeout=10s -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | wc -w)
    
    if [ "$ready_nodes" -eq "$total_nodes" ] && [ "$total_nodes" -gt 0 ]; then
        echo -e "${GREEN}✓ All ${total_nodes} nodes are Ready${NC}"
    else
        echo -e "${YELLOW}⚠️  ${ready_nodes}/${total_nodes} nodes are Ready${NC}"
    fi
    
    # Check system pods
    echo -e "\n${YELLOW}🔧 System Pods Status:${NC}"
    if KUBECONFIG="$kubeconfig" kubectl get pods -n kube-system --request-timeout=10s; then
        echo -e "${GREEN}✓ System pods information retrieved successfully${NC}"
    else
        echo -e "${RED}✗ Failed to get system pods information${NC}"
        return 1
    fi
    
    # Check for critical system pods (K3s specific)
    echo -e "\n${YELLOW}🎯 Critical System Pods Check (K3s):${NC}"
    local critical_pods=("coredns" "local-path-provisioner" "metrics-server")
    local all_ready=true
    
    for pod_prefix in "${critical_pods[@]}"; do
        local pod_status=$(KUBECONFIG="$kubeconfig" kubectl get pods -n kube-system --request-timeout=10s -o jsonpath="{.items[?(@.metadata.name=~'${pod_prefix}.*')].status.phase}" 2>/dev/null)
        if [[ "$pod_status" == *"Running"* ]]; then
            echo -e "${GREEN}✓ ${pod_prefix} pods are Running${NC}"
        else
            echo -e "${RED}✗ ${pod_prefix} pods are not Running (Status: ${pod_status})${NC}"
            all_ready=false
        fi
    done
    
    # Check for K3s specific components
    echo -e "\n${YELLOW}🎯 K3s Components Check:${NC}"
    
    # Check if K3s is running (should be a process, not a pod)
    if ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}" "systemctl is-active --quiet k3s" 2>/dev/null; then
        echo -e "${GREEN}✓ K3s service is active${NC}"
    else
        echo -e "${YELLOW}⚠️  K3s service status unknown (check manually)${NC}"
    fi
    
    # Check CNI and networking components (K3s specific)
    echo -e "\n${YELLOW}🌐 Networking Components Check (K3s):${NC}"
    
    # Check for Flannel (default K3s CNI)
    local flannel_pods=$(KUBECONFIG="$kubeconfig" kubectl get pods -n kube-system --request-timeout=10s -o jsonpath='{.items[?(@.metadata.name=~"flannel.*")].metadata.name}' 2>/dev/null)
    if [ -n "$flannel_pods" ]; then
        echo -e "${GREEN}✓ Flannel CNI pods found: ${flannel_pods}${NC}"
    else
        echo -e "${YELLOW}⚠️  No Flannel CNI pods found (K3s default)${NC}"
    fi
    
    # Check for Traefik ingress controller (K3s default)
    local traefik_pods=$(KUBECONFIG="$kubeconfig" kubectl get pods -n kube-system --request-timeout=10s -o jsonpath='{.items[?(@.metadata.name=~"traefik.*")].metadata.name}' 2>/dev/null)
    if [ -n "$traefik_pods" ]; then
        echo -e "${GREEN}✓ Traefik ingress controller found: ${traefik_pods}${NC}"
    else
        echo -e "${YELLOW}⚠️  No Traefik ingress controller found (K3s default)${NC}"
    fi
    
    # Check for svclb (service load balancer)
    local svclb_pods=$(KUBECONFIG="$kubeconfig" kubectl get pods -n kube-system --request-timeout=10s -o jsonpath='{.items[?(@.metadata.name=~"svclb.*")].metadata.name}' 2>/dev/null)
    if [ -n "$svclb_pods" ]; then
        echo -e "${GREEN}✓ Service load balancer pods found: ${svclb_pods}${NC}"
    else
        echo -e "${YELLOW}⚠️  No service load balancer pods found${NC}"
    fi
    
    # Check storage classes
    echo -e "\n${YELLOW}💾 Storage Classes:${NC}"
    if KUBECONFIG="$kubeconfig" kubectl get storageclass --request-timeout=10s; then
        echo -e "${GREEN}✓ Storage classes retrieved successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  No storage classes found or failed to retrieve${NC}"
    fi
    
    # Check namespaces
    echo -e "\n${YELLOW}📁 Namespaces:${NC}"
    if KUBECONFIG="$kubeconfig" kubectl get namespaces --request-timeout=10s; then
        echo -e "${GREEN}✓ Namespaces retrieved successfully${NC}"
    else
        echo -e "${RED}✗ Failed to get namespaces${NC}"
        return 1
    fi
    
    # Test basic functionality
    echo -e "\n${YELLOW}🧪 Testing Basic Cluster Functionality:${NC}"
    
    # Test pod creation
    echo -e "${YELLOW}  Testing pod creation...${NC}"
    if KUBECONFIG="$kubeconfig" kubectl run test-pod --image=busybox --restart=Never --command -- sleep 10 --request-timeout=10s >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓ Test pod created successfully${NC}"
        
        # Wait for pod to be ready
        sleep 5
        
        # Check pod status
        local pod_status=$(KUBECONFIG="$kubeconfig" kubectl get pod test-pod --request-timeout=10s -o jsonpath='{.status.phase}' 2>/dev/null)
        if [ "$pod_status" = "Running" ]; then
            echo -e "${GREEN}  ✓ Test pod is Running${NC}"
        else
            echo -e "${YELLOW}  ⚠️  Test pod status: ${pod_status}${NC}"
        fi
        
        # Clean up test pod
        KUBECONFIG="$kubeconfig" kubectl delete pod test-pod --request-timeout=10s >/dev/null 2>&1
        echo -e "${GREEN}  ✓ Test pod cleaned up${NC}"
    else
        echo -e "${RED}  ✗ Failed to create test pod${NC}"
        all_ready=false
    fi
    
    # K3s specific health checks
    echo -e "\n${YELLOW}🔧 K3s Cluster Health Summary:${NC}"
    
    # Check overall cluster health
    local cluster_health=$(KUBECONFIG="$kubeconfig" kubectl get nodes --request-timeout=10s -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    local healthy_nodes=$(echo "$cluster_health" | grep -o "True" | wc -l)
    local total_nodes=$(echo "$cluster_health" | wc -w)
    
    if [ "$healthy_nodes" -eq "$total_nodes" ] && [ "$total_nodes" -gt 0 ]; then
        echo -e "${GREEN}✓ Cluster Health: EXCELLENT (${healthy_nodes}/${total_nodes} nodes healthy)${NC}"
        all_ready=true
    elif [ "$healthy_nodes" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Cluster Health: DEGRADED (${healthy_nodes}/${total_nodes} nodes healthy)${NC}"
        all_ready=false
    else
        echo -e "${RED}✗ Cluster Health: CRITICAL (0/${total_nodes} nodes healthy)${NC}"
        all_ready=false
    fi
    
    # Check K3s version and components
    echo -e "\n${YELLOW}📊 K3s Version Information:${NC}"
    local k3s_version=$(KUBECONFIG="$kubeconfig" kubectl version --short --client 2>/dev/null | head -1)
    if [ -n "$k3s_version" ]; then
        echo -e "${GREEN}✓ ${k3s_version}${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not retrieve K3s version${NC}"
    fi
    
    # Overall status
    if [ "$all_ready" = true ]; then
        echo -e "\n${GREEN}🎉 K3s cluster verification completed successfully!${NC}"
        return 0
    else
        echo -e "\n${YELLOW}⚠️  K3s cluster verification completed with warnings${NC}"
        return 1
    fi
}

# Run verification if kubeconfig exists
if [ -f "output/kubeconfig" ]; then
    echo -e "\n${YELLOW}🔍 Running K3s cluster verification...${NC}"
    if verify_k3s_cluster "output/kubeconfig"; then
        echo -e "${GREEN}✓ K3s cluster verification passed${NC}"
    else
        echo -e "${YELLOW}⚠️  K3s cluster verification completed with issues${NC}"
        echo -e "${YELLOW}Please check the cluster manually:${NC}"
        echo -e "  export KUBECONFIG=\$PWD/output/kubeconfig"
        echo -e "  kubectl get nodes"
        echo -e "  kubectl get pods -n kube-system"
        echo -e "  kubectl get events -n kube-system --sort-by='.lastTimestamp'"
    fi
else
    echo -e "\n${YELLOW}⚠️  Skipping cluster verification - kubeconfig not found${NC}"
fi

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
echo "1. Export kubeconfig: export KUBECONFIG=\$PWD/output/kubeconfig"
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
