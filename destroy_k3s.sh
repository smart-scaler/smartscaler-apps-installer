#!/bin/bash

# K3s Cluster Destruction Script
# This script reads node information from user_input.yml and performs automated cleanup
# Based on the official K3s Ansible reset approach: https://github.com/k3s-io/k3s-ansible/blob/master/playbooks/reset.yml

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
        print_error "Make sure control_plane_nodes and/or worker_nodes are defined in user_input.yml"
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
    
    for node in $ALL_NODES; do
        if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$node" "echo 'SSH connection successful'" >/dev/null 2>&1; then
            print_error "Cannot connect to node $node via SSH"
            print_warning "Make sure SSH keys are properly configured and nodes are accessible"
            exit 1
        fi
        print_success "SSH connection to $node successful"
    done
}

# Function to stop K3s services on a node
stop_k3s_services() {
    local node=$1
    print_status "Stopping K3s services on $node..."
    
    ssh "$node" "
        # Stop K3s services
        if systemctl is-active --quiet k3s; then
            sudo systemctl stop k3s
            echo 'K3s service stopped'
        else
            echo 'K3s service not running'
        fi
        
        if systemctl is-active --quiet k3s-agent; then
            sudo systemctl stop k3s-agent
            echo 'K3s agent service stopped'
        else
            echo 'K3s agent service not running'
        fi
    "
}

# Function to uninstall K3s from a node (following official K3s Ansible reset approach)
uninstall_k3s() {
    local node=$1
    local is_master=$2
    print_status "Uninstalling K3s from $node (role: $([ "$is_master" = "true" ] && echo "server" || echo "agent"))..."
    
    ssh "$node" "
        # Run K3s uninstall scripts based on node role (following official K3s Ansible reset approach)
        if [ \"$is_master\" = \"true\" ]; then
            # Server node - run k3s-uninstall.sh
            if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
                sudo /usr/local/bin/k3s-uninstall.sh
                echo 'K3s server uninstall script completed'
            else
                echo 'K3s server uninstall script not found'
            fi
        else
            # Agent node - run k3s-agent-uninstall.sh
            if [ -f /usr/local/bin/k3s-agent-uninstall.sh ]; then
                sudo /usr/local/bin/k3s-agent-uninstall.sh
                echo 'K3s agent uninstall script completed'
            else
                echo 'K3s agent uninstall script not found'
            fi
        fi
    "
}

# Function to clean up system files and directories (following official K3s Ansible reset approach)
cleanup_system_files() {
    local node=$1
    local is_master=$2
    print_status "Cleaning up system files and directories on $node..."
    
    ssh "$node" "
        # Remove user kubeconfig (following official K3s Ansible reset approach)
        if [ -f ~/.kube/config ]; then
            rm -f ~/.kube/config
            echo 'Removed user kubeconfig'
        fi
        
        # Remove k3s install script
        if [ -f /usr/local/bin/k3s-install.sh ]; then
            sudo rm -f /usr/local/bin/k3s-install.sh
            echo 'Removed k3s install script'
        fi
        
        # Remove contents of K3s server location (if defined)
        if [ -d /var/lib/rancher/k3s ]; then
            sudo rm -rf /var/lib/rancher/k3s/*
            echo 'Removed contents of K3s server location'
        fi
        
        # Remove K3s config (following official approach)
        if [ -f /etc/rancher/k3s/config.yaml ]; then
            sudo rm -f /etc/rancher/k3s/config.yaml
            echo 'Removed K3s config'
        fi
        
        # Remove K3s binary and configuration files
        sudo rm -f /usr/local/bin/k3s
        sudo rm -f /usr/local/bin/k3s-agent
        sudo rm -f /usr/local/bin/kubectl
        sudo rm -f /usr/local/bin/crictl
        sudo rm -f /usr/local/bin/ctr
        
        # Remove systemd service files
        sudo rm -f /etc/systemd/system/k3s.service
        sudo rm -f /etc/systemd/system/k3s-agent.service
        
        # Reload systemd daemon
        sudo systemctl daemon-reload
        echo 'Systemd daemon reloaded'
    "
}

# Function to clean up network configuration
cleanup_network() {
    local node=$1
    print_status "Cleaning up network configuration on $node..."
    
    ssh "$node" "
        # Remove K3s network interfaces (if they exist)
        sudo ip link delete cni0 2>/dev/null || echo 'cni0 interface not found or already removed'
        sudo ip link delete flannel.1 2>/dev/null || echo 'flannel.1 interface not found or already removed'
        
        # Flush iptables rules (be careful in production environments)
        sudo iptables -F 2>/dev/null || echo 'iptables flush failed (may not be installed)'
        sudo iptables -t nat -F 2>/dev/null || echo 'iptables nat flush failed'
        sudo iptables -t mangle -F 2>/dev/null || echo 'iptables mangle flush failed'
        sudo iptables -X 2>/dev/null || echo 'iptables chain deletion failed'
        
        echo 'Network configuration cleaned up'
    "
}

# Function to clean up bashrc entries (following official K3s Ansible reset approach)
cleanup_bashrc() {
    local node=$1
    local is_master=$2
    print_status "Cleaning up bashrc entries on $node..."
    
    ssh "$node" "
        # Remove K3s commands from ~/.bashrc (following official K3s Ansible reset approach)
        if [ -f ~/.bashrc ]; then
            # Remove lines added by k3s-ansible
            sed -i '/Added by k3s-ansible/d' ~/.bashrc
            echo 'Cleaned up bashrc entries'
        fi
    "
}

# Function to reset node (optional)
reset_node() {
    local node=$1
    print_warning "Resetting node $node to clean state..."
    
    ssh "$node" "
        # Run k3s-killall script if it exists
        if [ -f /usr/local/bin/k3s-killall.sh ]; then
            sudo /usr/local/bin/k3s-killall.sh
            echo 'K3s killall script completed'
        else
            echo 'K3s killall script not found'
        fi
        
        echo 'Node reset completed'
    "
}

# Function to clean up local files
cleanup_local_files() {
    print_status "Cleaning up local K3s files..."
    
    # Remove local kubeconfig
    if [ -f "output/kubeconfig" ]; then
        rm -f "output/kubeconfig"
        print_success "Removed local kubeconfig file"
    fi
    
    # Remove local K3s inventory
    if [ -d "inventory/k3s" ]; then
        rm -rf "inventory/k3s"
        print_success "Removed local K3s inventory"
    fi
    
    # Remove local K3s ansible files
    if [ -d "k3s-ansible" ]; then
        rm -rf "k3s-ansible"
        print_success "Removed local K3s ansible files"
    fi
}

# Function to display confirmation prompt
confirm_destruction() {
    echo
    print_warning "This script will completely destroy your K3s cluster and remove all data!"
    echo
    echo "The following actions will be performed (following official K3s Ansible reset approach):"
    echo "  1. Stop K3s services on all nodes"
    echo "  2. Uninstall K3s from all nodes (server/agent based on role)"
    echo "  3. Clean up system files and directories"
    echo "  4. Clean up bashrc entries"
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
    echo "    K3s Cluster Destruction Script"
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
    
    # Check SSH connectivity
    check_ssh_connectivity
    
    # Confirm destruction
    confirm_destruction
    
    print_status "Starting K3s cluster destruction..."
    echo
    
    # Calculate total steps (4 main steps per node + bashrc cleanup + local cleanup)
    local total_steps=$(( $(echo "$ALL_NODES" | wc -w) * 5 + 1 ))
    local current_step=0
    
    # Process each node
    for node in $ALL_NODES; do
        print_status "Processing node: $node"
        
        # Determine if this is a master node
        local is_master="false"
        if echo "$MASTER_NODES" | grep -q "$node"; then
            is_master="true"
        fi
        
        # Stop K3s services
        current_step=$((current_step + 1))
        show_progress $current_step $total_steps
        stop_k3s_services "$node"
        
        # Uninstall K3s
        current_step=$((current_step + 1))
        show_progress $current_step $total_steps
        uninstall_k3s "$node" "$is_master"
        
        # Clean up system files
        current_step=$((current_step + 1))
        show_progress $current_step $total_steps
        cleanup_system_files "$node" "$is_master"
        
        # Clean up bashrc entries
        cleanup_bashrc "$node" "$is_master"
        
        # Clean up network configuration
        current_step=$((current_step + 1))
        show_progress $current_step $total_steps
        cleanup_network "$node"
        
        # Reset node (optional)
        reset_node "$node"
        
        print_success "Node $node cleanup completed"
        echo
    done
    
    # Clean up local files
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps
    cleanup_local_files
    
    echo
    print_success "K3s cluster destruction completed successfully!"
    echo
    print_warning "All nodes have been reset to their pre-K3s state"
    print_warning "You may need to reboot nodes if you encounter any issues"
    echo
    print_status "To verify cleanup, you can check:"
    echo "  - No K3s processes running: ps aux | grep k3s"
    echo "  - No K3s services: systemctl list-units | grep k3s"
    echo "  - No K3s files: ls -la /usr/local/bin/ | grep k3s"
    echo "  - No K3s directories: ls -la /var/lib/ | grep -E '(rancher|kubelet)'"
}

# Trap to handle script interruption
trap 'echo -e "\n${RED}[ERROR]${NC} Script interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"
