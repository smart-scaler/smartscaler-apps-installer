#!/bin/bash

# Smart Scaler Master Deployment Script
# This script automates the complete deployment process for Smart Scaler
# Author: Smart Scaler Team
# Version: 1.0

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/deployment.log"
VENV_DIR="$SCRIPT_DIR/venv"
SSH_KEY_PATH="$HOME/.ssh/k8s_rsa"

# Default values
REMOTE_DEPLOY=false
SKIP_PREREQUISITES=false
SKIP_K8S_SETUP=false
SKIP_APP_DEPLOYMENT=false
SKIP_VALIDATION=false
IGNORE_DEPLOYMENT_ERRORS=false
DEBUG_MODE=false
MASTER_NODE_IP=""
MASTER_NODE_USER="root"
KUBECONFIG_REMOTE_PATH="/etc/kubernetes/admin.conf"
KUBECONFIG_LOCAL_PATH="$SCRIPT_DIR/files/kubeconfig"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to validate configuration using validate_config.py
validate_configuration() {
    print_status "Validating Smart Scaler configuration..."

    # Check if validate_config.py exists
    if [ ! -f "files/validate_config.py" ]; then
        print_error "files/validate_config.py not found"
        print_status "This script validates your user_input.yml configuration"
        print_status "Please ensure validate_config.py is in the files/ directory"
        exit 1
    fi

    # Check if user_input.yml exists
    if [ ! -f "user_input.yml" ]; then
        print_error "user_input.yml not found"
        print_status "Please create and configure user_input.yml before running deployment"
        exit 1
    fi

    # Run configuration validation
    print_status "Running configuration validation (non-interactive mode)..."
    
    # Create a temporary script to run validation non-interactively
    python3 << 'EOF'
import sys
import os
sys.path.insert(0, os.getcwd())

# Import and run validation with modified main function
exec(open('files/validate_config.py').read().replace(
    'test_connectivity = input("\\nTest SSH connectivity to nodes? [y/N]: ").lower().startswith(\'y\')',
    'test_connectivity = True  # Auto-enable SSH connectivity test'
))
EOF

    local validation_result=$?
    
    if [ $validation_result -eq 0 ]; then
        print_success "Configuration validation passed"
        return 0
    else
        print_error "Configuration validation failed"
        print_status "Please fix the configuration errors before proceeding"
        print_status "You can also run validation manually: python3 files/validate_config.py"
        exit 1
    fi
}

# Function to print usage
usage() {
    cat << EOF
Smart Scaler Master Deployment Script

Usage: $0 [OPTIONS]

Options:
    -h, --help                  Show this help message
    -r, --remote                Force remote deployment mode
    -m, --master-ip IP          Master node IP address (auto-detected from user_input.yml if not specified)
    -u, --master-user USER      Master node SSH user (auto-detected from user_input.yml if not specified)
    -k, --kubeconfig-path PATH  Remote kubeconfig path (default: /etc/kubernetes/admin.conf)
    --skip-prereq              Skip prerequisites installation
    --skip-k8s                  Skip Kubernetes setup
    --skip-apps                 Skip application deployment
    --skip-validation           Skip configuration validation
    --ignore-errors             Ignore all deployment errors and continue (debug mode)
    --debug                   Enable debug mode
    --ngc-api-key KEY          NGC API Key
    --ngc-docker-key KEY       NGC Docker API Key
    --avesha-username USER     Avesha Docker username
    --avesha-password PASS     Avesha Docker password

Environment Variables:
    NGC_API_KEY                NGC API Key for NVIDIA components
    NGC_DOCKER_API_KEY         NGC Docker API Key
    AVESHA_DOCKER_USERNAME     Avesha Docker registry username
    AVESHA_DOCKER_PASSWORD     Avesha Docker registry password

Deployment Modes:
    Local Mode:  All components run on the local machine (when kubeconfig is available locally)
    Remote Mode: Applications are deployed from the master node (automatically used when needed)
    
    The script automatically detects the appropriate mode:
    - If kubeconfig exists locally: Uses local mode
    - If kubeconfig must be retrieved from master: Switches to remote mode
    - If --remote flag is used: Forces remote mode

Configuration Validation:
    The script automatically validates your user_input.yml configuration before deployment:
    - Validates YAML syntax and required fields
    - Tests SSH connectivity to all nodes
    - Verifies privilege escalation settings
    - Checks IP address formats and SSH key permissions
    
    Use --skip-validation to bypass this step (not recommended).

Examples:
    # Automatic deployment with validation (recommended)
    $0

    # Force remote deployment
    $0 --remote

    # Remote deployment with specific master node
    $0 --remote --master-ip 192.168.1.100 --master-user ubuntu

    # Skip Kubernetes setup (cluster already exists)
    $0 --skip-k8s

    # Deploy only applications (prerequisites and K8s already done)
    $0 --skip-prereq --skip-k8s

    # Skip configuration validation (not recommended)
    $0 --skip-validation

    # Ignore all errors and continue deployment (debug mode)
    $0 --ignore-errors

    # Combination: Remote deployment ignoring errors
    $0 --remote --master-ip 192.168.1.100 --ignore-errors

    # Validate configuration only (manual validation)
    python3 files/validate_config.py

    # Check documentation
    See docs/DEPLOY_SMARTSCALER_GUIDE.md for detailed usage guide

EOF
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate prerequisites
validate_system_prerequisites() {
    print_status "Validating system prerequisites..."

    # Check for required system commands
    local missing_commands=()
    
    if ! command_exists python3; then
        missing_commands+=(python3)
    fi
    
    if ! command_exists pip3; then
        missing_commands+=(python3-pip)
    fi
    
    if ! command_exists git; then
        missing_commands+=(git)
    fi
    
    if ! command_exists ssh; then
        missing_commands+=(openssh-client)
    fi

    if [ ${#missing_commands[@]} -ne 0 ]; then
        print_error "Missing required commands: ${missing_commands[*]}"
        print_status "Installing missing packages..."
        sudo apt-get update
        sudo apt-get install -y "${missing_commands[@]}"
    fi

    # Check Python version
    local python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    local min_version="3.8"
    
    if ! printf '%s\n%s\n' "$min_version" "$python_version" | sort -V -C; then
        print_error "Python version $python_version is too old. Minimum required: $min_version"
        exit 1
    fi

    print_success "System prerequisites validated"
}

# Function to setup environment variables
setup_environment_variables() {
    print_status "Setting up environment variables..."

    # Check if environment variables are already set
    local env_vars_set=true
    
    if [ -z "$NGC_API_KEY" ]; then
        if [ -n "$CLI_NGC_API_KEY" ]; then
            export NGC_API_KEY="$CLI_NGC_API_KEY"
        else
            env_vars_set=false
        fi
    fi
    
    if [ -z "$NGC_DOCKER_API_KEY" ]; then
        if [ -n "$CLI_NGC_DOCKER_KEY" ]; then
            export NGC_DOCKER_API_KEY="$CLI_NGC_DOCKER_KEY"
        else
            env_vars_set=false
        fi
    fi
    
    if [ -z "$AVESHA_DOCKER_USERNAME" ]; then
        if [ -n "$CLI_AVESHA_USERNAME" ]; then
            export AVESHA_DOCKER_USERNAME="$CLI_AVESHA_USERNAME"
        else
            env_vars_set=false
        fi
    fi
    
    if [ -z "$AVESHA_DOCKER_PASSWORD" ]; then
        if [ -n "$CLI_AVESHA_PASSWORD" ]; then
            export AVESHA_DOCKER_PASSWORD="$CLI_AVESHA_PASSWORD"
        else
            env_vars_set=false
        fi
    fi

    if [ "$env_vars_set" = false ]; then
        print_warning "Some required environment variables are not set."
        print_status "You can set them manually or provide them via command line arguments."
        print_status "Required variables: NGC_API_KEY, NGC_DOCKER_API_KEY, AVESHA_DOCKER_USERNAME, AVESHA_DOCKER_PASSWORD"
        
        # Prompt for missing variables
        if [ -z "$NGC_API_KEY" ]; then
            read -s -p "Enter NGC API Key: " NGC_API_KEY
            echo
            export NGC_API_KEY
        fi
        
        if [ -z "$NGC_DOCKER_API_KEY" ]; then
            read -s -p "Enter NGC Docker API Key: " NGC_DOCKER_API_KEY
            echo
            export NGC_DOCKER_API_KEY
        fi
        
        if [ -z "$AVESHA_DOCKER_USERNAME" ]; then
            read -p "Enter Avesha Docker Username: " AVESHA_DOCKER_USERNAME
            export AVESHA_DOCKER_USERNAME
        fi
        
        if [ -z "$AVESHA_DOCKER_PASSWORD" ]; then
            read -s -p "Enter Avesha Docker Password: " AVESHA_DOCKER_PASSWORD
            echo
            export AVESHA_DOCKER_PASSWORD
        fi
    fi

    print_success "Environment variables configured"
}

# Function to install prerequisites
install_prerequisites() {
    print_status "Installing prerequisites..."

    # Create virtual environment if it doesn't exist
    if [ ! -d "$VENV_DIR" ]; then
        print_status "Creating Python virtual environment..."
        python3 -m venv "$VENV_DIR"
    fi

    # Activate virtual environment
    print_status "Activating virtual environment..."
    source "$VENV_DIR/bin/activate"

    # Upgrade pip
    print_status "Upgrading pip..."
    pip install --upgrade pip

    # Install Python dependencies
    print_status "Installing Python dependencies..."
    pip install -r requirements.txt

    # Install Ansible collections
    print_status "Installing Ansible collections..."
    ansible-galaxy collection install -r requirements.yml

    print_success "Prerequisites installed successfully"
}

# Function to setup SSH keys
setup_ssh_keys() {
    print_status "Setting up SSH keys..."

    if [ ! -f "$SSH_KEY_PATH" ]; then
        print_status "Generating SSH key for cluster access..."
        ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
        print_success "SSH key generated: $SSH_KEY_PATH"
    else
        print_status "SSH key already exists: $SSH_KEY_PATH"
    fi

    # Set proper permissions
    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "${SSH_KEY_PATH}.pub"

    print_status "SSH keys configured"
}

# Function to copy SSH key to remote nodes
copy_ssh_keys() {
    print_status "Copying SSH keys to remote nodes..."

    # Read node information from user_input.yml
    python3 << 'EOF'
import yaml
import subprocess
import sys
import os

try:
    with open('user_input.yml', 'r') as f:
        data = yaml.safe_load(f)
    
    # Get nodes from kubernetes_deployment section
    k8s_config = data.get('kubernetes_deployment', {})
    if not k8s_config.get('enabled', False):
        print("Kubernetes deployment is disabled. Skipping SSH key copy.")
        sys.exit(0)
    
    all_nodes = []
    all_nodes.extend(k8s_config.get('control_plane_nodes', []))
    all_nodes.extend(k8s_config.get('worker_nodes', []))
    
    default_user = k8s_config.get('default_ansible_user', 'root')
    ssh_key_path = os.path.expanduser('~/.ssh/k8s_rsa')
    
    for node in all_nodes:
        host = node['ansible_host']
        user = node.get('ansible_user', default_user)
        node_name = node['name']
        
        print(f"Copying SSH key to {node_name} ({user}@{host})...")
        
        # Check if the key already exists on the remote host
        check_cmd = f"ssh -i {ssh_key_path} -o StrictHostKeyChecking=no -o BatchMode=yes {user}@{host} 'echo SSH key test successful'"
        try:
            subprocess.run(check_cmd, shell=True, check=True, capture_output=True)
            print(f"✓ SSH key already accessible for {node_name}")
            continue
        except subprocess.CalledProcessError:
            print(f"  SSH key needs to be copied to {node_name}")
        
        # Copy SSH key
        cmd = f"ssh-copy-id -i {ssh_key_path}.pub {user}@{host}"
        try:
            subprocess.run(cmd, shell=True, check=True)
            print(f"✓ SSH key copied to {node_name}")
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to copy SSH key to {node_name}: {e}")
            print(f"  Please manually copy the SSH key or ensure password-less access")
            print(f"  Command: {cmd}")
            # Don't exit on SSH key copy failure, as it might already be configured
            continue

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
EOF

    if [ $? -eq 0 ]; then
        print_success "SSH key copy process completed"
    else
        print_error "Failed to process SSH keys"
        exit 1
    fi
}

# Function to run Kubernetes setup
setup_kubernetes() {
    print_status "Setting up Kubernetes cluster..."

    # Ensure virtual environment is activated
    source "$VENV_DIR/bin/activate"

    # Make setup script executable
    chmod +x setup_kubernetes.sh

    # Set ignore errors flag for Ansible
    if [ "$IGNORE_DEPLOYMENT_ERRORS" = true ]; then
        print_warning "IGNORE ERRORS MODE ENABLED - Deployment will continue despite errors"
        export ANSIBLE_EXTRA_VARS="ignore_deployment_errors=true"
    else
        export ANSIBLE_EXTRA_VARS="ignore_deployment_errors=false"
    fi

    # Run Kubernetes setup
    ./setup_kubernetes.sh

    if [ $? -eq 0 ]; then
        print_success "Kubernetes cluster setup completed"
    else
        if [ "$IGNORE_DEPLOYMENT_ERRORS" = true ]; then
            print_warning "Kubernetes cluster setup had errors but continuing due to --ignore-errors flag"
        else
            print_error "Kubernetes cluster setup failed"
            exit 1
        fi
    fi
}

# Function to validate kubeconfig
validate_kubeconfig() {
    print_status "Validating kubeconfig on remote node..."

    # Get master node info if not already set
    if [ -z "$MASTER_NODE_IP" ]; then
        print_status "Getting master node information from user_input.yml..."
        
        MASTER_INFO=$(python3 << 'EOF'
import yaml
import sys

try:
    with open('user_input.yml', 'r') as f:
        data = yaml.safe_load(f)
    
    k8s_config = data.get('kubernetes_deployment', {})
    control_plane_nodes = k8s_config.get('control_plane_nodes', [])
    
    if not control_plane_nodes:
        print("ERROR: No control plane nodes found in user_input.yml")
        sys.exit(1)
    
    # Use the first control plane node
    master_node = control_plane_nodes[0]
    master_ip = master_node['ansible_host']
    master_user = master_node.get('ansible_user', k8s_config.get('default_ansible_user', 'root'))
    
    print(f"{master_ip}|{master_user}")
    
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
EOF
)
        
        if [[ $MASTER_INFO == ERROR:* ]]; then
            print_error "${MASTER_INFO#ERROR: }"
            exit 1
        fi
        
        IFS='|' read -r MASTER_NODE_IP MASTER_NODE_USER <<< "$MASTER_INFO"
    fi

    # Test kubectl connectivity on remote node
    ssh -T -o LogLevel=QUIET -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY_PATH" "$MASTER_NODE_USER@$MASTER_NODE_IP" << 'EOF' >/dev/null 2>&1
# Create a temporary copy of admin.conf with proper permissions
sudo cp /etc/kubernetes/admin.conf /tmp/admin.conf >/dev/null 2>&1
sudo chown $(whoami) /tmp/admin.conf >/dev/null 2>&1
export KUBECONFIG=/tmp/admin.conf

print_status() {
    echo "[INFO] $1"
}

print_success() {
    echo "[SUCCESS] $1"
}

print_status "Checking cluster connectivity..."
if kubectl cluster-info >/dev/null 2>&1; then
    print_success "Kubeconfig is valid and cluster is accessible"
    
    if [ "$DEBUG_MODE" = "true" ]; then
        echo
        echo "[DEBUG] Cluster information:"
        kubectl cluster-info
        echo
        kubectl get nodes
    fi
    
    # Clean up temporary kubeconfig
    rm -f /tmp/admin.conf >/dev/null 2>&1
    exit 0
else
    # Clean up temporary kubeconfig
    rm -f /tmp/admin.conf >/dev/null 2>&1
    echo "[ERROR] Failed to connect to Kubernetes cluster"
    echo "[INFO] Please ensure the Kubernetes deployment completed successfully"
    exit 1
fi
EOF

    if [ $? -ne 0 ]; then
        print_error "Failed to validate kubeconfig on remote node"
        exit 1
    fi
}

# Function to deploy Smart Scaler applications
deploy_applications() {
    print_status "Deploying Smart Scaler applications..."

    # Determine deployment location based on remote flag
    if [ "$REMOTE_DEPLOY" = true ] || [ -n "$MASTER_NODE_IP" ]; then
        deploy_applications_remote
    else
        deploy_applications_local
    fi
}

# Function to deploy applications locally
deploy_applications_local() {
    print_status "Deploying applications locally..."

    # Ensure virtual environment is activated
    source "$VENV_DIR/bin/activate"

    # Set KUBECONFIG for the deployment
    export KUBECONFIG="$KUBECONFIG_LOCAL_PATH"

    # Run the main deployment playbook
    ansible-playbook site.yml \
        -e "ngc_api_key=$NGC_API_KEY" \
        -e "ngc_docker_api_key=$NGC_DOCKER_API_KEY" \
        -e "avesha_docker_username=$AVESHA_DOCKER_USERNAME" \
        -e "avesha_docker_password=$AVESHA_DOCKER_PASSWORD" \
        -vv

    if [ $? -eq 0 ]; then
        print_success "Smart Scaler applications deployed successfully (local)"
    else
        print_error "Smart Scaler application deployment failed (local)"
        exit 1
    fi
}

# Function to deploy applications remotely on master node
deploy_applications_remote() {
    print_status "Deploying applications remotely on master node..."

    # Get master node info if not already set
    if [ -z "$MASTER_NODE_IP" ]; then
        print_status "Getting master node information from user_input.yml..."
        
        MASTER_INFO=$(python3 << 'EOF'
import yaml
import sys

try:
    with open('user_input.yml', 'r') as f:
        data = yaml.safe_load(f)
    
    k8s_config = data.get('kubernetes_deployment', {})
    control_plane_nodes = k8s_config.get('control_plane_nodes', [])
    
    if not control_plane_nodes:
        print("ERROR: No control plane nodes found in user_input.yml")
        sys.exit(1)
    
    # Use the first control plane node
    master_node = control_plane_nodes[0]
    master_ip = master_node['ansible_host']
    master_user = master_node.get('ansible_user', k8s_config.get('default_ansible_user', 'root'))
    
    print(f"{master_ip}|{master_user}")
    
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
EOF
)
        
        if [[ $MASTER_INFO == ERROR:* ]]; then
            print_error "${MASTER_INFO#ERROR: }"
            exit 1
        fi
        
        IFS='|' read -r MASTER_NODE_IP MASTER_NODE_USER <<< "$MASTER_INFO"
    fi

    print_status "Using master node for deployment: $MASTER_NODE_USER@$MASTER_NODE_IP"

    # Create a temporary directory for deployment
    LOCAL_TEMP_DIR=$(mktemp -d)
    DEPLOYMENT_ZIP="$LOCAL_TEMP_DIR/deployment.zip"
    REMOTE_DEPLOY_DIR="/tmp/smartscaler-deployment-$(date +%s)"
    
    print_status "Creating deployment package..."
    
    # Files and directories to copy
    COPY_FILES=(
        "site.yml"
        "user_input.yml"
        "requirements.txt"
        "requirements.yml"
        "ansible.cfg"
        "tasks/"
        "roles/"
        "templates/"
        "files/"
        "group_vars/"
        "host_vars/"
    )
    
    # Create zip file with all required files
    (cd "$SCRIPT_DIR" && zip -q -r "$DEPLOYMENT_ZIP" "${COPY_FILES[@]}" 2>/dev/null)

    # Create remote directory and copy zip file
    print_status "Copying deployment package to remote host..."
    scp -q -o LogLevel=QUIET -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY_PATH" "$DEPLOYMENT_ZIP" "$MASTER_NODE_USER@$MASTER_NODE_IP:$REMOTE_DEPLOY_DIR/deployment.zip" 2>/dev/null

    if [ $? -ne 0 ]; then
        print_error "Failed to copy deployment package"
        rm -rf "$LOCAL_TEMP_DIR"
        exit 1
    fi

    print_status "Setting up remote environment and running deployment..."
    
    # Execute deployment on remote master node
    ssh -T -o LogLevel=QUIET -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY_PATH" "$MASTER_NODE_USER@$MASTER_NODE_IP" << EOF >/dev/null 2>&1
cd "$REMOTE_DEPLOY_DIR"
unzip -q deployment.zip
rm -f deployment.zip

# Export environment variables
export NGC_API_KEY="$NGC_API_KEY"
export NGC_DOCKER_API_KEY="$NGC_DOCKER_API_KEY"
export AVESHA_DOCKER_USERNAME="$AVESHA_DOCKER_USERNAME"
export AVESHA_DOCKER_PASSWORD="$AVESHA_DOCKER_PASSWORD"
export KUBECONFIG="$KUBECONFIG_REMOTE_PATH"

# Check if python3 and pip are installed silently
command -v python3 >/dev/null 2>&1 || { sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y python3 python3-pip python3-venv >/dev/null 2>&1; }

# Create virtual environment
python3 -m venv venv >/dev/null 2>&1
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip >/dev/null 2>&1

# Install dependencies
pip install -r requirements.txt >/dev/null 2>&1
ansible-galaxy collection install -r requirements.yml >/dev/null 2>&1

# Run deployment
ansible-playbook site.yml \
    -e "ngc_api_key=\$NGC_API_KEY" \
    -e "ngc_docker_api_key=\$NGC_DOCKER_API_KEY" \
    -e "avesha_docker_username=\$AVESHA_DOCKER_USERNAME" \
    -e "avesha_docker_password=\$AVESHA_DOCKER_PASSWORD" \
    -vv
EOF

    DEPLOYMENT_EXIT_CODE=$?

    # Cleanup
    rm -rf "$LOCAL_TEMP_DIR"
    ssh -T -o LogLevel=QUIET -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY_PATH" "$MASTER_NODE_USER@$MASTER_NODE_IP" "rm -rf $REMOTE_DEPLOY_DIR" >/dev/null 2>&1

    if [ $DEPLOYMENT_EXIT_CODE -eq 0 ]; then
        print_success "Smart Scaler applications deployed successfully (remote)"
    else
        print_error "Smart Scaler application deployment failed (remote)"
        print_status "Check the logs above for detailed error information"
        exit 1
    fi
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."

    # Always use remote verification when we have a master node IP
    if [ -n "$MASTER_NODE_IP" ]; then
        verify_deployment_remote
    else
        verify_deployment_local
    fi
}

# Function to verify deployment locally
verify_deployment_local() {
    export KUBECONFIG="$KUBECONFIG_LOCAL_PATH"

    print_status "Checking namespaces..."
    kubectl get namespaces

    print_status "Checking pods in all namespaces..."
    kubectl get pods --all-namespaces

    print_status "Checking services..."
    kubectl get svc --all-namespaces

    print_status "Checking KEDA ScaledObjects..."
    kubectl get scaledobjects --all-namespaces 2>/dev/null || echo "No KEDA ScaledObjects found"

    print_success "Deployment verification completed (local)"
}

# Function to verify deployment remotely
verify_deployment_remote() {
    print_status "Verifying deployment remotely on master node: $MASTER_NODE_IP"

    # Create a temporary directory for output
    local temp_dir=$(mktemp -d)
    local output_file="$temp_dir/deployment_verification.txt"

    ssh -T -o LogLevel=QUIET -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$MASTER_NODE_USER@$MASTER_NODE_IP" << EOF 2>/dev/null > "$output_file"
# Create a temporary copy of admin.conf with proper permissions
sudo cp /etc/kubernetes/admin.conf /tmp/admin.conf
sudo chown \$(whoami) /tmp/admin.conf
export KUBECONFIG=/tmp/admin.conf

echo "=== Cluster Information ==="
kubectl cluster-info

echo ""
echo "=== Node Status ==="
kubectl get nodes -o wide

echo ""
echo "=== All Namespaces ==="
kubectl get namespaces

echo ""
echo "=== Pods in All Namespaces ==="
kubectl get pods --all-namespaces

echo ""
echo "=== Services in All Namespaces ==="  
kubectl get svc --all-namespaces

echo ""
echo "=== Cluster Health Check ==="
kubectl get componentstatuses 2>/dev/null || echo "ComponentStatus API not available (expected in newer K8s versions)"

echo ""
echo "=== Storage Classes ==="
kubectl get storageclass

echo ""
echo "=== KEDA ScaledObjects (if any) ==="
kubectl get scaledobjects --all-namespaces 2>/dev/null || echo "No KEDA ScaledObjects found or KEDA not installed yet"

# Clean up temporary kubeconfig
rm -f /tmp/admin.conf
EOF

    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        print_success "Deployment verification completed successfully (remote)"
        print_status "Kubernetes cluster is running and accessible on $MASTER_NODE_IP"
        
        if [ "$DEBUG_MODE" = "true" ]; then
            echo
            print_status "Debug information saved to deployment_verification.zip"
            # Create a zip file with the verification output
            (cd "$temp_dir" && zip deployment_verification.zip deployment_verification.txt)
            mv "$temp_dir/deployment_verification.zip" .
            echo "To view the complete verification output, unzip deployment_verification.zip"
        fi
    else
        print_warning "Some verification commands failed, but deployment may still be successful"
        print_status "You can manually check the cluster with: ssh -i $SSH_KEY_PATH $MASTER_NODE_USER@$MASTER_NODE_IP"
    fi

    # Cleanup
    rm -rf "$temp_dir"
}

# Function to display final status
display_final_status() {
    print_success "Smart Scaler deployment completed successfully!"
    echo
    
    if [ -n "$MASTER_NODE_IP" ]; then
        print_status "REMOTE DEPLOYMENT - Cluster running on: $MASTER_NODE_USER@$MASTER_NODE_IP"
        echo
        print_status "Access your cluster remotely:"
        echo "1. SSH to master node:"
        echo "   ssh -i $SSH_KEY_PATH $MASTER_NODE_USER@$MASTER_NODE_IP"
        echo
        echo "2. Check cluster status (on remote master):"
        echo "   export KUBECONFIG=/etc/kubernetes/admin.conf"
        echo "   kubectl get nodes"
        echo "   kubectl get pods --all-namespaces"
        echo
        echo "3. Access services via port forwarding from master:"
        echo "   # Grafana dashboard"
        echo "   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 --address 0.0.0.0"
        echo "   # Then access: http://$MASTER_NODE_IP:3000"
        echo
        echo "   # Prometheus"
        echo "   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 --address 0.0.0.0"
        echo "   # Then access: http://$MASTER_NODE_IP:9090"
        echo
        echo "   # NIM service endpoint"
        echo "   kubectl port-forward -n nim svc/meta-llama3-8b-instruct 8000:8000 --address 0.0.0.0"
        echo "   # Then access: http://$MASTER_NODE_IP:8000"
        echo
        echo "4. Monitor scaling with KEDA (on remote master):"
        echo "   kubectl get scaledobjects -n nim"
        echo "   kubectl get hpa -n nim"
        echo
        print_status "Remote cluster management commands:"
        echo "ssh -i $SSH_KEY_PATH $MASTER_NODE_USER@$MASTER_NODE_IP 'kubectl get nodes'"
        echo "ssh -i $SSH_KEY_PATH $MASTER_NODE_USER@$MASTER_NODE_IP 'kubectl get pods --all-namespaces'"
    else
        print_status "LOCAL DEPLOYMENT - Next steps:"
        echo "1. Access Grafana dashboard for monitoring"
        echo "   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
        echo
        echo "2. Access Prometheus for metrics"
        echo "   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
        echo
        echo "3. Test NIM service endpoint"
        echo "   kubectl port-forward -n nim svc/meta-llama3-8b-instruct 8000:8000"
        echo
        echo "4. Monitor scaling with KEDA"
        echo "   kubectl get scaledobjects -n nim"
    fi
    
    echo
    echo "5. View deployment logs:"
    echo "   tail -f $LOG_FILE"
    echo
    print_status "For troubleshooting, refer to the README.md documentation"
}

# Main execution function
main() {
    print_status "Starting Smart Scaler Master Deployment Script"
    print_status "Log file: $LOG_FILE"
    echo

    # Change to script directory
    cd "$SCRIPT_DIR"

    # Validate configuration unless skipped
    if [ "$SKIP_VALIDATION" = false ]; then
        validate_configuration
    else
        print_warning "Skipping configuration validation"
    fi

    # Validate system prerequisites
    if [ "$SKIP_PREREQUISITES" = false ]; then
        validate_system_prerequisites
        setup_environment_variables
        install_prerequisites
        setup_ssh_keys
        copy_ssh_keys
    else
        print_warning "Skipping prerequisites installation"
        setup_environment_variables
        # Still activate virtual environment if it exists
        if [ -d "$VENV_DIR" ]; then
            source "$VENV_DIR/bin/activate"
        fi
    fi

    # Setup Kubernetes cluster
    if [ "$SKIP_K8S_SETUP" = false ]; then
        setup_kubernetes
    else
        print_warning "Skipping Kubernetes setup"
    fi

    # Validate kubeconfig
    validate_kubeconfig

    # Deploy applications
    if [ "$SKIP_APP_DEPLOYMENT" = false ]; then
        deploy_applications
        verify_deployment
    else
        print_warning "Skipping application deployment"
    fi

    # Display final status
    display_final_status
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -r|--remote)
            REMOTE_DEPLOY=true
            shift
            ;;
        -m|--master-ip)
            MASTER_NODE_IP="$2"
            shift 2
            ;;
        -u|--master-user)
            MASTER_NODE_USER="$2"
            shift 2
            ;;
        -k|--kubeconfig-path)
            KUBECONFIG_REMOTE_PATH="$2"
            shift 2
            ;;
        --skip-prereq)
            SKIP_PREREQUISITES=true
            shift
            ;;
        --skip-k8s)
            SKIP_K8S_SETUP=true
            shift
            ;;
        --skip-apps)
            SKIP_APP_DEPLOYMENT=true
            shift
            ;;
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        --ignore-errors)
            IGNORE_DEPLOYMENT_ERRORS=true
            shift
            ;;
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        --ngc-api-key)
            CLI_NGC_API_KEY="$2"
            shift 2
            ;;
        --ngc-docker-key)
            CLI_NGC_DOCKER_KEY="$2"
            shift 2
            ;;
        --avesha-username)
            CLI_AVESHA_USERNAME="$2"
            shift 2
            ;;
        --avesha-password)
            CLI_AVESHA_PASSWORD="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate remote deployment requirements
if [ "$REMOTE_DEPLOY" = true ] && [ -z "$MASTER_NODE_IP" ]; then
    print_error "Remote deployment requires master node IP address (-m|--master-ip)"
    usage
    exit 1
fi

# Create log file
touch "$LOG_FILE"

# Trap to handle script interruption
trap 'print_error "Script interrupted"; exit 1' INT TERM

# Run main function
main

print_success "Smart Scaler deployment script completed successfully!"