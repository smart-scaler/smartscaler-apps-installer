# Smart Scaler Deployment Guide

## Overview

The `deploy_smartscaler.sh` script is a comprehensive master deployment automation tool that handles the complete Smart Scaler deployment process. It integrates configuration validation, prerequisite installation, Kubernetes cluster setup, and Smart Scaler application deployment.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Command Line Options](#command-line-options)
- [Deployment Modes](#deployment-modes)
- [Configuration Validation](#configuration-validation)
- [Environment Variables](#environment-variables)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

## Prerequisites

### System Requirements

- **Operating System**: Ubuntu 20.04+ or CentOS 7+
- **Python**: 3.8 or higher
- **Memory**: Minimum 4GB RAM (8GB+ recommended)
- **Storage**: 50GB+ free space
- **Network**: Internet connectivity for downloading packages

### Required Packages

The script automatically installs missing packages, but you can pre-install:

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv git openssh-client

# CentOS/RHEL
sudo yum install -y python3 python3-pip git openssh-clients
```

### API Keys and Credentials

Before deployment, obtain the following credentials:

1. **NGC API Key**: From NVIDIA NGC (https://ngc.nvidia.com)
2. **NGC Docker API Key**: For accessing NVIDIA containers
3. **Avesha Docker Credentials**: Username and password for Avesha registry

## Quick Start

### 1. Prepare Configuration

Create and configure `user_input.yml`:

```bash
cp user_input.yml.example user_input.yml
# Edit user_input.yml with your cluster configuration
```

### 2. Set Environment Variables

```bash
export NGC_API_KEY="your_ngc_api_key"
export NGC_DOCKER_API_KEY="your_ngc_docker_key"
export AVESHA_DOCKER_USERNAME="your_avesha_username"
export AVESHA_DOCKER_PASSWORD="your_avesha_password"
```

### 3. Run Deployment

```bash
# Full automatic deployment with validation
./deploy_smartscaler.sh

# Check help for all options
./deploy_smartscaler.sh --help
```

## Configuration

### user_input.yml Structure

The deployment requires a properly configured `user_input.yml` file:

```yaml
kubernetes_deployment:
  enabled: true
  ssh_key_path: "~/.ssh/k8s_rsa"
  default_ansible_user: "ubuntu"  # or "root"
  
  control_plane_nodes:
    - name: "master-1"
      ansible_host: "192.168.1.100"
      ansible_user: "ubuntu"
      ansible_become: true
      ansible_become_method: "sudo"
      ansible_become_user: "root"
      private_ip: "10.0.1.100"
  
  worker_nodes:
    - name: "worker-1"
      ansible_host: "192.168.1.101"
      ansible_user: "ubuntu"
      ansible_become: true
      ansible_become_method: "sudo"
      ansible_become_user: "root"
      private_ip: "10.0.1.101"

# Additional configurations...
```

### Node Configuration Examples

#### Root User Configuration
```yaml
control_plane_nodes:
  - name: "master-1"
    ansible_host: "192.168.1.100"
    ansible_user: "root"
    # No privilege escalation needed
```

#### Non-Root User with Sudo
```yaml
control_plane_nodes:
  - name: "master-1"
    ansible_host: "192.168.1.100"
    ansible_user: "ubuntu"
    ansible_become: true
    ansible_become_method: "sudo"
    ansible_become_user: "root"
```

#### Mixed Configuration
```yaml
control_plane_nodes:
  - name: "master-1"
    ansible_host: "192.168.1.100"
    ansible_user: "root"
  - name: "master-2"
    ansible_host: "192.168.1.101"
    ansible_user: "ubuntu"
    ansible_become: true
    ansible_become_method: "sudo"
    ansible_become_user: "root"
```

## Command Line Options

### Basic Options

| Option | Description | Example |
|--------|-------------|---------|
| `-h, --help` | Show help message | `./deploy_smartscaler.sh --help` |
| `-r, --remote` | Force remote deployment mode | `./deploy_smartscaler.sh --remote` |
| `-m, --master-ip IP` | Specify master node IP | `./deploy_smartscaler.sh -m 192.168.1.100` |
| `-u, --master-user USER` | Specify master node SSH user | `./deploy_smartscaler.sh -u ubuntu` |
| `-k, --kubeconfig-path PATH` | Remote kubeconfig path | `./deploy_smartscaler.sh -k /etc/kubernetes/admin.conf` |

### Skip Options

| Option | Description | Use Case |
|--------|-------------|----------|
| `--skip-prereq` | Skip prerequisites installation | Prerequisites already installed |
| `--skip-k8s` | Skip Kubernetes setup | Cluster already exists |
| `--skip-apps` | Skip application deployment | Deploy infrastructure only |
| `--skip-validation` | Skip configuration validation | Trust configuration (not recommended) |

### Credential Options

| Option | Description | Alternative to Environment Variable |
|--------|-------------|-----------------------------------|
| `--ngc-api-key KEY` | NGC API Key | `NGC_API_KEY` |
| `--ngc-docker-key KEY` | NGC Docker API Key | `NGC_DOCKER_API_KEY` |
| `--avesha-username USER` | Avesha Docker username | `AVESHA_DOCKER_USERNAME` |
| `--avesha-password PASS` | Avesha Docker password | `AVESHA_DOCKER_PASSWORD` |

## Deployment Modes

### Local Mode

**When Used**: 
- Kubeconfig is available locally
- Running on the master node
- Local kubectl access configured

**Process**:
1. Uses local kubeconfig (`files/kubeconfig` or `~/.kube/config`)
2. Deploys applications from local machine
3. Faster execution as no remote file copying

**Example**:
```bash
# Automatic local mode detection
./deploy_smartscaler.sh
```

### Remote Mode

**When Used**:
- Running from external machine
- Kubeconfig must be retrieved from master
- No local kubectl access

**Process**:
1. Retrieves kubeconfig from remote master
2. Copies deployment files to master node
3. Executes deployment on master node
4. Cleans up temporary files

**Example**:
```bash
# Force remote mode
./deploy_smartscaler.sh --remote

# Remote with specific master
./deploy_smartscaler.sh --remote --master-ip 192.168.1.100 --master-user ubuntu
```

### Automatic Mode Detection

The script automatically detects the appropriate mode:

1. **Checks for local kubeconfig**:
   - `files/kubeconfig`
   - `/etc/kubernetes/admin.conf`
   - `~/.kube/config`

2. **If not found locally**:
   - Switches to remote mode
   - Retrieves from master node

3. **If `--remote` flag used**:
   - Forces remote mode regardless

## Configuration Validation

### Automatic Validation

The script automatically validates configuration before deployment:

#### Validation Steps:
1. **YAML Syntax**: Checks `user_input.yml` syntax
2. **Required Fields**: Validates mandatory configuration fields
3. **IP Address Format**: Verifies IP address validity
4. **SSH Key Validation**: Checks SSH key existence and permissions
5. **SSH Connectivity**: Tests connection to all nodes
6. **Privilege Escalation**: Verifies sudo access for non-root users

#### Validation Output:
```bash
[INFO] Smart Scaler Configuration Validator
==================================================
[INFO] Validating Kubernetes deployment configuration...
[INFO] Validating 1 control plane node(s)...
[INFO] Validating control plane node 1: master-1
[INFO] Validating 2 worker node(s)...
[SUCCESS] SSH connectivity successful: master-1 (ubuntu@192.168.1.100)
[SUCCESS] Sudo privilege escalation successful: master-1
[SUCCESS] Configuration validation passed!
```

### Manual Validation

Run validation independently:

```bash
# Interactive validation
python3 files/validate_config.py

# Check SSH connectivity
ssh -i ~/.ssh/k8s_rsa ubuntu@192.168.1.100 'echo "Connection test"'

# Test sudo access
ssh -i ~/.ssh/k8s_rsa ubuntu@192.168.1.100 'sudo whoami'
```

### Skip Validation (Not Recommended)

```bash
./deploy_smartscaler.sh --skip-validation
```

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NGC_API_KEY` | NVIDIA NGC API key | `nvapi-xxx...` |
| `NGC_DOCKER_API_KEY` | NGC Docker registry key | `nvdocker-xxx...` |
| `AVESHA_DOCKER_USERNAME` | Avesha registry username | `your-username` |
| `AVESHA_DOCKER_PASSWORD` | Avesha registry password | `your-password` |

### Setting Environment Variables

#### Method 1: Export Commands
```bash
export NGC_API_KEY="your_ngc_api_key"
export NGC_DOCKER_API_KEY="your_ngc_docker_key"
export AVESHA_DOCKER_USERNAME="your_avesha_username"
export AVESHA_DOCKER_PASSWORD="your_avesha_password"
```

#### Method 2: Environment File
```bash
# Create .env file
cat > .env << EOF
NGC_API_KEY=your_ngc_api_key
NGC_DOCKER_API_KEY=your_ngc_docker_key
AVESHA_DOCKER_USERNAME=your_avesha_username
AVESHA_DOCKER_PASSWORD=your_avesha_password
EOF

# Source the file
source .env
```

#### Method 3: Command Line Arguments
```bash
./deploy_smartscaler.sh \
  --ngc-api-key "your_ngc_api_key" \
  --ngc-docker-key "your_ngc_docker_key" \
  --avesha-username "your_avesha_username" \
  --avesha-password "your_avesha_password"
```

## Usage Examples

### Complete Deployment Examples

#### 1. Fresh Deployment (Recommended)
```bash
# Set environment variables
export NGC_API_KEY="your_key"
export NGC_DOCKER_API_KEY="your_docker_key"
export AVESHA_DOCKER_USERNAME="your_username"
export AVESHA_DOCKER_PASSWORD="your_password"

# Configure user_input.yml, then run:
./deploy_smartscaler.sh
```

#### 2. Remote Deployment
```bash
./deploy_smartscaler.sh \
  --remote \
  --master-ip 192.168.1.100 \
  --master-user ubuntu \
  --ngc-api-key "your_key" \
  --ngc-docker-key "your_docker_key" \
  --avesha-username "your_username" \
  --avesha-password "your_password"
```

#### 3. Incremental Deployment
```bash
# Install prerequisites only
./deploy_smartscaler.sh --skip-k8s --skip-apps

# Setup Kubernetes only
./deploy_smartscaler.sh --skip-prereq --skip-apps

# Deploy applications only
./deploy_smartscaler.sh --skip-prereq --skip-k8s
```

#### 4. Development/Testing Scenarios
```bash
# Skip validation for trusted config
./deploy_smartscaler.sh --skip-validation

# Kubernetes cluster already exists
./deploy_smartscaler.sh --skip-k8s

# Test configuration only
python3 files/validate_config.py
```

### Deployment Workflow Examples

#### Production Deployment Workflow
```bash
# 1. Validate configuration
python3 files/validate_config.py

# 2. Deploy infrastructure
./deploy_smartscaler.sh --skip-apps

# 3. Verify cluster
kubectl get nodes
kubectl get pods --all-namespaces

# 4. Deploy applications
./deploy_smartscaler.sh --skip-prereq --skip-k8s
```

#### CI/CD Pipeline Example
```bash
#!/bin/bash
set -e

# Set credentials from CI/CD secrets
export NGC_API_KEY="$CI_NGC_API_KEY"
export NGC_DOCKER_API_KEY="$CI_NGC_DOCKER_KEY"
export AVESHA_DOCKER_USERNAME="$CI_AVESHA_USERNAME"
export AVESHA_DOCKER_PASSWORD="$CI_AVESHA_PASSWORD"

# Deploy with validation
./deploy_smartscaler.sh

# Verify deployment
kubectl get pods --all-namespaces
kubectl get scaledobjects --all-namespaces
```

## Troubleshooting

### Common Issues and Solutions

#### 1. SSH Connection Failures

**Error**: `SSH connectivity failed: master-1 (ubuntu@192.168.1.100)`

**Solutions**:
```bash
# Check SSH key permissions
chmod 600 ~/.ssh/k8s_rsa
chmod 644 ~/.ssh/k8s_rsa.pub

# Test SSH connection manually
ssh -i ~/.ssh/k8s_rsa ubuntu@192.168.1.100

# Copy SSH key manually if needed
ssh-copy-id -i ~/.ssh/k8s_rsa.pub ubuntu@192.168.1.100
```

#### 2. Privilege Escalation Failures

**Error**: `Sudo privilege escalation failed: master-1`

**Solutions**:
```bash
# Check sudo configuration on remote host
ssh -i ~/.ssh/k8s_rsa ubuntu@192.168.1.100 'sudo -n whoami'

# Configure passwordless sudo (on remote host)
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ubuntu
```

#### 3. Kubeconfig Permission Issues

**Error**: `Permission denied: /etc/kubernetes/admin.conf`

**Solutions**:
```bash
# The script handles this automatically, but for manual troubleshooting:
# On master node:
sudo cp /etc/kubernetes/admin.conf /tmp/kubeconfig_temp
sudo chown ubuntu:ubuntu /tmp/kubeconfig_temp
sudo chmod 644 /tmp/kubeconfig_temp

# Then copy locally:
scp -i ~/.ssh/k8s_rsa ubuntu@master:/tmp/kubeconfig_temp files/kubeconfig
```

#### 4. Environment Variable Issues

**Error**: Environment variables not set

**Solutions**:
```bash
# Verify environment variables
echo $NGC_API_KEY
echo $NGC_DOCKER_API_KEY
echo $AVESHA_DOCKER_USERNAME

# Use command line arguments instead
./deploy_smartscaler.sh \
  --ngc-api-key "your_key" \
  --ngc-docker-key "your_docker_key" \
  --avesha-username "your_username" \
  --avesha-password "your_password"
```

### Log Analysis

#### Deployment Logs
```bash
# View real-time logs
tail -f deployment.log

# Search for errors
grep -i error deployment.log
grep -i failed deployment.log

# Check specific deployment phases
grep "Installing prerequisites" deployment.log
grep "Setting up Kubernetes" deployment.log
grep "Deploying applications" deployment.log
```

#### Kubernetes Cluster Logs
```bash
# Check node status
kubectl get nodes -o wide

# Check pod status
kubectl get pods --all-namespaces

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check specific namespace
kubectl get pods -n smart-scaler
kubectl describe pods -n smart-scaler
```

### Recovery Procedures

#### Partial Deployment Recovery
```bash
# If deployment failed during Kubernetes setup
./deploy_smartscaler.sh --skip-prereq

# If deployment failed during application deployment
./deploy_smartscaler.sh --skip-prereq --skip-k8s

# Clean restart (removes existing cluster)
# WARNING: This will destroy existing cluster
sudo kubeadm reset -f
./deploy_smartscaler.sh
```

#### Configuration Fixes
```bash
# Re-run validation after configuration changes
python3 files/validate_config.py

# Test individual components
./deploy_smartscaler.sh --skip-k8s --skip-apps  # Prerequisites only
./deploy_smartscaler.sh --skip-prereq --skip-apps  # Kubernetes only
./deploy_smartscaler.sh --skip-prereq --skip-k8s   # Applications only
```

## Advanced Configuration

### Custom SSH Configuration

#### Using Custom SSH Keys
```yaml
# In user_input.yml
kubernetes_deployment:
  ssh_key_path: "/path/to/custom/key"
```

#### SSH Config File
```bash
# ~/.ssh/config
Host master-*
    User ubuntu
    IdentityFile ~/.ssh/k8s_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host worker-*
    User ubuntu
    IdentityFile ~/.ssh/k8s_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

### Network Configuration

#### Custom Network Settings
```yaml
# In user_input.yml
kubernetes_deployment:
  control_plane_nodes:
    - name: "master-1"
      ansible_host: "public.ip.address"
      private_ip: "internal.ip.address"  # Used for cluster communication
```

### High Availability Setup

#### Multi-Master Configuration
```yaml
kubernetes_deployment:
  control_plane_nodes:
    - name: "master-1"
      ansible_host: "192.168.1.100"
      private_ip: "10.0.1.100"
    - name: "master-2"
      ansible_host: "192.168.1.101"
      private_ip: "10.0.1.101"
    - name: "master-3"
      ansible_host: "192.168.1.102"
      private_ip: "10.0.1.102"
```

### Performance Tuning

#### Large Cluster Deployment
```bash
# Increase timeouts for large clusters
export ANSIBLE_TIMEOUT=300
export ANSIBLE_SSH_TIMEOUT=300

# Use parallel deployment
./deploy_smartscaler.sh
```

#### Resource Optimization
```bash
# Monitor resource usage during deployment
watch 'kubectl top nodes; kubectl top pods --all-namespaces'

# Check deployment progress
watch 'kubectl get pods --all-namespaces | grep -v Running | grep -v Completed'
```

### Integration with External Tools

#### Terraform Integration
```bash
# After Terraform provisions infrastructure
terraform output -json > cluster_info.json

# Update user_input.yml with Terraform outputs
# Then run deployment
./deploy_smartscaler.sh
```

#### Ansible Integration
```bash
# Use deployment script in Ansible playbook
- name: Deploy Smart Scaler
  shell: ./deploy_smartscaler.sh
  args:
    chdir: /path/to/smartscaler-apps-installer
  environment:
    NGC_API_KEY: "{{ ngc_api_key }}"
    NGC_DOCKER_API_KEY: "{{ ngc_docker_key }}"
    AVESHA_DOCKER_USERNAME: "{{ avesha_username }}"
    AVESHA_DOCKER_PASSWORD: "{{ avesha_password }}"
```

## Support and Resources

### Getting Help

- **Documentation**: Check `docs/` directory for detailed guides
- **Validation**: Run `python3 files/validate_config.py` for configuration issues
- **Logs**: Check `deployment.log` for detailed execution logs
- **Community**: Refer to project repository for issues and discussions

### Useful Commands

```bash
# Quick health check
kubectl get nodes
kubectl get pods --all-namespaces

# Access services
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
kubectl port-forward -n nim svc/meta-llama3-8b-instruct 8000:8000

# Monitor scaling
kubectl get scaledobjects --all-namespaces
kubectl get hpa --all-namespaces
```

### Best Practices

1. **Always validate configuration** before deployment
2. **Use environment variables** for sensitive credentials
3. **Test SSH connectivity** to all nodes before deployment
4. **Monitor logs** during deployment for early error detection
5. **Backup configurations** before making changes
6. **Use incremental deployment** for troubleshooting
7. **Verify cluster state** after each deployment phase 