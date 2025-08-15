#!/bin/bash

# K8s Cluster Destruction Script
# This script reads node information from user_input.yml and performs automated cleanup
# Based on the Kubespray reset approach for Kubernetes clusters

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if file exists
file_exists() {
    [ -f "$1" ]
}

# Function to check if directory exists
dir_exists() {
    [ -d "$1" ]
}

# Function to check if user_input.yml exists
check_user_input() {
    if [ ! -f "user_input.yml" ]; then
        print_error "user_input.yml not found in current directory"
        exit 1
    fi
}

# Function to extract node information from user_input.yml
extract_nodes() {
    print_status "Extracting node information from user_input.yml..."
    
    # Extract master nodes from control_plane_nodes array (under kubernetes_deployment)
    MASTER_NODES=$(python3 -c "
import yaml
with open('user_input.yml', 'r') as f:
    data = yaml.safe_load(f)
masters = []
if 'kubernetes_deployment' in data and 'control_plane_nodes' in data['kubernetes_deployment']:
    for node in data['kubernetes_deployment']['control_plane_nodes']:
        if 'ansible_host' in node:
            masters.append(node['ansible_host'])
print(' '.join(masters))
" 2>/dev/null || echo "")
    
    # Extract worker nodes from worker_nodes array (under kubernetes_deployment)
    WORKER_NODES=$(python3 -c "
import yaml
with open('user_input.yml', 'r') as f:
    data = yaml.safe_load(f)
workers = []
if 'kubernetes_deployment' in data and 'worker_nodes' in data['kubernetes_deployment']:
    for node in data['kubernetes_deployment']['worker_nodes']:
        if 'ansible_host' in node:
            workers.append(node['ansible_host'])
print(' '.join(workers))
" 2>/dev/null || echo "")
    
    # Extract all nodes (masters + workers)
    ALL_NODES=$(python3 -c "
import yaml
with open('user_input.yml', 'r') as f:
    data = yaml.safe_load(f)
nodes = []
if 'kubernetes_deployment' in data and 'control_plane_nodes' in data['kubernetes_deployment']:
    for node in data['kubernetes_deployment']['control_plane_nodes']:
        if 'ansible_host' in node:
            nodes.append(node['ansible_host'])
if 'kubernetes_deployment' in data and 'worker_nodes' in data['kubernetes_deployment']:
    for node in data['kubernetes_deployment']['worker_nodes']:
        if 'ansible_host' in node:
            nodes.append(node['ansible_host'])
print(' '.join(nodes))
" 2>/dev/null || echo "")
    
    if [ -z "$ALL_NODES" ]; then
        print_error "Could not extract node information from user_input.yml"
        print_error "Make sure control_plane_nodes and/or worker_nodes are defined in kubernetes_deployment section"
        exit 1
    fi
    
    print_success "Found nodes:"
    if [ -n "$MASTER_NODES" ]; then
        echo "  Master nodes: $MASTER_NODES"
    fi
    if [ -n "$WORKER_NODES" ]; then
        echo "  Worker nodes: $WORKER_NODES"
    fi
    echo "  All nodes: $ALL_NODES"
}

# Function to check SSH connectivity
check_ssh_connectivity() {
    print_status "Checking SSH connectivity to all nodes..."
    
    # Extract SSH key path from user_input.yml
    local ssh_key_path=$(python3 -c "
import yaml
with open('user_input.yml', 'r') as f:
    data = yaml.safe_load(f)
if 'kubernetes_deployment' in data and 'ssh_key_path' in data['kubernetes_deployment']:
    print(data['kubernetes_deployment']['ssh_key_path'])
else:
    print('')
" 2>/dev/null || echo "")
    
    if [ -z "$ssh_key_path" ]; then
        print_error "Could not extract SSH key path from user_input.yml"
        exit 1
    fi
    
    # Expand the SSH key path
    ssh_key_path=$(echo "$ssh_key_path" | sed 's/^~/$HOME/')
    
    if [ ! -f "$ssh_key_path" ]; then
        print_error "SSH key file not found at: $ssh_key_path"
        exit 1
    fi
    
    print_status "Using SSH key: $ssh_key_path"
    
    for node in $ALL_NODES; do
        if ! ssh -i "$ssh_key_path" -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no "$node" "echo 'SSH connection successful'" >/dev/null 2>&1; then
            print_error "Cannot connect to node $node via SSH"
            print_warning "Make sure SSH keys are properly configured and nodes are accessible"
            print_warning "SSH key path: $ssh_key_path"
            exit 1
        fi
        print_success "SSH connection to $node successful"
    done
}

# Function to stop Kubernetes services on a node
stop_k8s_services() {
    local node=$1
    local ssh_key_path=$2
    print_status "Stopping Kubernetes services on $node..."
    
    ssh -i "$ssh_key_path" -o StrictHostKeyChecking=no "$node" "
        # Stop kubelet service
        if systemctl is-active --quiet kubelet; then
            sudo systemctl stop kubelet
            echo 'Kubelet service stopped'
        else
            echo 'Kubelet service not running'
        fi
        
        # Stop containerd service
        if systemctl is-active --quiet containerd; then
            sudo systemctl stop containerd
            echo 'Containerd service stopped'
        else
            echo 'Containerd service not running'
        fi
        
        # Stop docker service (if using docker runtime)
        if systemctl is-active --quiet docker; then
            sudo systemctl stop docker
            echo 'Docker service stopped'
        else
            echo 'Docker service not running'
        fi
    "
}

# Function to clean up Kubernetes files and directories
cleanup_k8s_files() {
    local node=$1
    local ssh_key_path=$2
    print_status "Cleaning up Kubernetes files and directories on $node..."
    
    ssh -i "$ssh_key_path" -o StrictHostKeyChecking=no "$node" "
        # Remove Kubernetes configuration directories
        if [ -d /etc/kubernetes ]; then
            sudo rm -rf /etc/kubernetes
            echo 'Removed /etc/kubernetes'
        fi
        
        if [ -d /var/lib/kubelet ]; then
            sudo rm -rf /var/lib/kubelet
            echo 'Removed /var/lib/kubelet'
        fi
        
        if [ -d /var/lib/etcd ]; then
            sudo rm -rf /var/lib/etcd
            echo 'Removed /var/lib/etcd'
        fi
        
        if [ -d /var/lib/cni ]; then
            sudo rm -rf /var/lib/cni
            echo 'Removed /var/lib/cni'
        fi
        
        if [ -d /etc/cni ]; then
            sudo rm -rf /etc/cni
            echo 'Removed /etc/cni'
        fi
        
        # Remove containerd data
        if [ -d /var/lib/containerd ]; then
            sudo rm -rf /var/lib/containerd
            echo 'Removed /var/lib/containerd'
        fi
        
        # Remove docker data (if using docker runtime)
        if [ -d /var/lib/docker ]; then
            sudo rm -rf /var/lib/docker
            echo 'Removed /var/lib/docker'
        fi
        
        # Remove user kubeconfig
        if [ -f ~/.kube/config ]; then
            rm -f ~/.kube/config
            echo 'Removed user kubeconfig'
        fi
        
        # Clean up HAProxy load balancer files and processes
        echo 'Cleaning up HAProxy load balancer...'
        
        # Stop HAProxy service if running
        if systemctl is-active --quiet haproxy; then
            sudo systemctl stop haproxy
            echo 'Stopped HAProxy service'
        fi
        
        # Remove HAProxy configuration
        if [ -f /etc/haproxy/haproxy.cfg ]; then
            sudo rm -f /etc/haproxy/haproxy.cfg
            echo 'Removed HAProxy configuration'
        fi
        
        # Remove HAProxy data directory
        if [ -d /var/lib/haproxy ]; then
            sudo rm -rf /var/lib/haproxy
            echo 'Removed HAProxy data directory'
        fi
        
        # Kill any remaining HAProxy processes
        sudo pkill -f haproxy 2>/dev/null || echo 'No HAProxy processes found'
        
        # Remove HAProxy log files
        if [ -d /var/log/haproxy ]; then
            sudo rm -rf /var/log/haproxy
            echo 'Removed HAProxy log files'
        fi
    "
}

# Function to clean up network configuration
cleanup_network() {
    local node=$1
    local ssh_key_path=$2
    print_status "Cleaning up network configuration on $node..."
    
    ssh -i "$ssh_key_path" -o StrictHostKeyChecking=no "$node" "
        # Remove CNI network interfaces
        sudo ip link delete cni0 2>/dev/null || echo 'cni0 interface not found or already removed'
        sudo ip link delete flannel.1 2>/dev/null || echo 'flannel.1 interface not found or already removed'
        sudo ip link delete calico_net 2>/dev/null || echo 'calico_net interface not found or already removed'
        
        # Flush iptables rules (be careful in production environments)
        sudo iptables -F 2>/dev/null || echo 'iptables flush failed (may not be installed)'
        sudo iptables -t nat -F 2>/dev/null || echo 'iptables nat flush failed'
        sudo iptables -t mangle -F 2>/dev/null || echo 'iptables mangle flush failed'
        sudo iptables -X 2>/dev/null || echo 'iptables chain deletion failed'
        
        # Remove CNI configuration files
        sudo rm -f /etc/cni/net.d/*
        echo 'Network configuration cleaned up'
    "
}

# Function to reset node (optional)
reset_node() {
    local node=$1
    local ssh_key_path=$2
    print_warning "Resetting node $node to clean state..."
    
    ssh -i "$ssh_key_path" -o StrictHostKeyChecking=no "$node" "
        # Kill any remaining Kubernetes processes
        sudo pkill -f kubelet 2>/dev/null || echo 'No kubelet processes found'
        sudo pkill -f containerd 2>/dev/null || echo 'No containerd processes found'
        sudo pkill -f docker 2>/dev/null || echo 'No docker processes found'
        
        echo 'Node reset completed'
    "
}

# Function to run Kubespray reset playbook
run_kubespray_reset() {
    print_status "Running Kubespray reset playbook..."
    
    # Check if kubespray directory exists
    if [ ! -d "kubespray" ]; then
        print_warning "Kubespray directory not found, skipping official reset"
        print_warning "This means we'll only do manual cleanup"
        return 0
    fi
    
    # Check if kubespray inventory exists
    if [ ! -d "inventory/kubespray" ]; then
        print_warning "Kubespray inventory not found, skipping official reset"
        print_warning "This means we'll only do manual cleanup"
        return 0
    fi
    
    # Check if kubespray reset playbook exists
    if [ ! -f "kubespray/playbooks/reset.yml" ]; then
        print_warning "Kubespray reset playbook not found, skipping official reset"
        print_warning "This means we'll only do manual cleanup"
        return 0
    fi
    
    print_status "Found Kubespray installation, running official reset playbook..."
    
    # Run the reset playbook from root directory
    if ansible-playbook kubespray/reset.yml -i inventory/kubespray/inventory.ini --become --become-user=root; then
        print_success "Kubespray reset playbook completed successfully"
    else
        print_warning "Kubespray reset playbook failed, continuing with manual cleanup"
        print_warning "This is normal if the cluster was already partially destroyed"
    fi
}

# Function to clean up local files
cleanup_local_files() {
    print_status "Cleaning up local Kubernetes files..."
    
    # Remove local kubeconfig
    if [ -f "output/kubeconfig" ]; then
        rm -f "output/kubeconfig"
        print_success "Removed local kubeconfig file"
    fi
    
    # Remove local Kubespray inventory
    if [ -d "inventory/kubespray" ]; then
        rm -rf "inventory/kubespray"
        print_success "Removed local Kubespray inventory"
    fi
    
    # Remove local Kubespray files
    if [ -d "kubespray" ]; then
        rm -rf "kubespray"
        print_success "Removed local Kubespray files"
    fi
    
    # Clean up local HAProxy configurations
    print_status "Cleaning up local HAProxy configurations..."
    
    # Remove any local HAProxy config files
    if [ -f "haproxy.cfg" ]; then
        rm -f "haproxy.cfg"
        print_success "Removed local HAProxy configuration"
    fi
    
    # Remove any local HAProxy directories
    if [ -d "haproxy" ]; then
        rm -rf "haproxy"
        print_success "Removed local HAProxy directory"
    fi
    
    # Remove any HAProxy manifests
    if [ -f "haproxy-manifest.yaml" ]; then
        rm -f "haproxy-manifest.yaml"
        print_success "Removed local HAProxy manifest"
    fi
}

# Function to display confirmation prompt
confirm_destruction() {
    echo
    print_warning "This script will completely destroy your Kubernetes cluster and remove all data!"
    echo
    echo "The following actions will be performed:"
    echo "  1. Run Kubespray reset playbook (if available)"
    echo "  2. Stop Kubernetes services on all nodes"
    echo "  3. Clean up Kubernetes files and directories"
    echo "  4. Clean up HAProxy load balancer (if present)"
    echo "  5. Clean up network configuration"
    echo "  6. Reset nodes to clean state"
    echo "  7. Clean up local files"
    echo
    echo "Nodes to be affected: $ALL_NODES"
    echo
    read -p "Are you absolutely sure you want to proceed? (yes/no): " -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Cluster destruction cancelled by user"
        exit 0
    fi
    
    echo
    read -p "Type 'DESTROY' to confirm: " -r
    echo
    
    if [[ ! $REPLY =~ ^DESTROY$ ]]; then
        print_status "Cluster destruction cancelled - confirmation text did not match"
        exit 0
    fi
}

# Function to display progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '#'
    printf "%${remaining}s" | tr ' ' '-'
    printf "] %d%%" $percentage
    
    if [ $current -eq $total ]; then
        echo
    fi
}

# Main execution function
main() {
    echo "=========================================="
    echo "    K8s Cluster Destruction Script"
    echo "=========================================="
    echo
    
    # Check prerequisites
    check_user_input
    
    # Check if required tools are available
    if ! command_exists python3; then
        print_error "Python3 is required but not installed"
        exit 1
    fi
    
    if ! command_exists ssh; then
        print_error "SSH client is required but not installed"
        exit 1
    fi
    
    # Extract node information
    extract_nodes
    
    # Extract SSH key path from user_input.yml
    local ssh_key_path=$(python3 -c "
import yaml
with open('user_input.yml', 'r') as f:
    data = yaml.safe_load(f)
if 'kubernetes_deployment' in data and 'ssh_key_path' in data['kubernetes_deployment']:
    print(data['kubernetes_deployment']['ssh_key_path'])
else:
    print('')
" 2>/dev/null || echo "")

    if [ -z "$ssh_key_path" ]; then
        print_error "Could not extract SSH key path from user_input.yml"
        exit 1
    fi
    
    # Expand the SSH key path
    ssh_key_path=$(echo "$ssh_key_path" | sed 's/^~/$HOME/')
    
    if [ ! -f "$ssh_key_path" ]; then
        print_error "SSH key file not found at: $ssh_key_path"
        exit 1
    fi
    
    print_status "Using SSH key: $ssh_key_path"
    
    # Check SSH connectivity
    check_ssh_connectivity
    
    # Confirm destruction
    confirm_destruction
    
    print_status "Starting Kubernetes cluster destruction..."
    echo
    
    # Calculate total steps (Kubespray reset + 3 main steps per node + local cleanup)
    local total_steps=$(( 1 + $(echo "$ALL_NODES" | wc -w) * 3 + 1 ))
    local current_step=0
    
    # Step 1: Run Kubespray reset playbook (if available)
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps
    run_kubespray_reset
    
    # Process each node
    for node in $ALL_NODES; do
        print_status "Processing node: $node"
        
        # Stop Kubernetes services
        current_step=$((current_step + 1))
        show_progress $current_step $total_steps
        stop_k8s_services "$node" "$ssh_key_path"
        
        # Clean up Kubernetes files
        current_step=$((current_step + 1))
        show_progress $current_step $total_steps
        cleanup_k8s_files "$node" "$ssh_key_path"
        
        # Clean up network configuration
        current_step=$((current_step + 1))
        show_progress $current_step $total_steps
        cleanup_network "$node" "$ssh_key_path"
        
        # Reset node (optional)
        reset_node "$node" "$ssh_key_path"
        
        print_success "Node $node cleanup completed"
        echo
    done
    
    # Clean up local files
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps
    cleanup_local_files
    
    echo
    print_success "Kubernetes cluster destruction completed successfully!"
    echo
    print_warning "All nodes have been reset to their pre-Kubernetes state"
    print_warning "You may need to reboot nodes if you encounter any issues"
    echo
    print_status "To verify cleanup, you can check:"
    echo "  - No Kubernetes processes running: ps aux | grep -E '(kubelet|containerd|docker)'"
    echo "  - No Kubernetes services: systemctl list-units | grep -E '(kubelet|containerd|docker)'"
    echo "  - No Kubernetes directories: ls -la /etc/ | grep -E '(kubernetes|cni)'"
    echo "  - No Kubernetes data: ls -la /var/lib/ | grep -E '(kubelet|etcd|cni|containerd|docker)'"
}

# Trap to handle script interruption
trap 'echo -e "\n${RED}[ERROR]${NC} Script interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"
