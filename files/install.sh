#!/bin/bash

# Smart Scaler Installation Script
# This script automates the initial setup and prerequisites installation

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root"
    exit 1
fi

# Check system requirements
print_status "Checking system requirements..."

# Check OS
if ! grep -q "Ubuntu" /etc/os-release; then
    print_warning "This script is optimized for Ubuntu. Your mileage may vary on other distributions."
fi

# Check Python version
if ! command -v python3 >/dev/null 2>&1; then
    print_error "Python 3 is required but not installed"
    print_status "Installing Python 3..."
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv
fi

python_version=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
if printf '%s\n%s\n' "3.8" "$python_version" | sort -V -C; then
    print_success "Python version $python_version is compatible"
else
    print_error "Python version $python_version is too old. Minimum required: 3.8"
    exit 1
fi

# Check Git
if ! command -v git >/dev/null 2>&1; then
    print_error "Git is required but not installed"
    print_status "Installing Git..."
    sudo apt-get update
    sudo apt-get install -y git
fi

# Check SSH
if ! command -v ssh >/dev/null 2>&1; then
    print_error "SSH is required but not installed"
    print_status "Installing SSH..."
    sudo apt-get update
    sudo apt-get install -y openssh-client
fi

# Clone repository
print_status "Cloning Smart Scaler repository..."
if [ ! -d "smartscaler-apps-installer" ]; then
    git clone https://github.com/smart-scaler/smartscaler-apps-installer.git
fi
cd smartscaler-apps-installer

# Create virtual environment
print_status "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install dependencies
print_status "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Install Ansible collections
print_status "Installing Ansible collections..."
ansible-galaxy collection install -r requirements.yml

# Generate SSH key if it doesn't exist
if [ ! -f "$HOME/.ssh/k8s_rsa" ]; then
    print_status "Generating SSH key for cluster access..."
    ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/k8s_rsa" -N ""
    print_success "SSH key generated: $HOME/.ssh/k8s_rsa"
    print_status "Please copy this key to your cluster nodes:"
    echo "ssh-copy-id -i $HOME/.ssh/k8s_rsa.pub user@node-ip"
fi

# Check for required environment variables
print_status "Checking environment variables..."
ENV_VARS_SET=true

check_env_var() {
    if [ -z "${!1}" ]; then
        print_warning "$1 is not set"
        ENV_VARS_SET=false
    fi
}

check_env_var "NGC_API_KEY"
check_env_var "NGC_DOCKER_API_KEY"
check_env_var "AVESHA_DOCKER_USERNAME"
check_env_var "AVESHA_DOCKER_PASSWORD"

if [ "$ENV_VARS_SET" = false ]; then
    print_warning "Some required environment variables are not set"
    print_status "Please set them before running deploy_smartscaler.sh:"
    echo "export NGC_API_KEY=your-ngc-api-key"
    echo "export NGC_DOCKER_API_KEY=your-ngc-docker-key"
    echo "export AVESHA_DOCKER_USERNAME=your-username"
    echo "export AVESHA_DOCKER_PASSWORD=your-password"
fi

# Make deployment script executable
chmod +x deploy_smartscaler.sh

print_success "Installation completed successfully!"
echo
print_status "Next steps:"
echo "1. Set the required environment variables (if not already set)"
echo "2. Configure user_input.yml with your cluster settings"
echo "3. Run ./deploy_smartscaler.sh to deploy Smart Scaler"
echo
print_status "For detailed documentation, visit:"
echo "https://github.com/smart-scaler/smartscaler-apps-installer/blob/main/README.md" 