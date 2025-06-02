# Node Configuration Guide for Smart Scaler Deployment

## Overview
This guide explains how to properly configure nodes in `user_input.yml` for Smart Scaler deployment, including privilege escalation settings for non-root users.

## Configuration Structure

### Basic Node Configuration
```yaml
kubernetes_deployment:
  enabled: true
  default_ansible_user: "ubuntu"  # Default user for all nodes
  ssh_key_path: "/home/user/.ssh/k8s_rsa"
  
  control_plane_nodes:
    - name: master-k8s
      ansible_host: "192.168.1.100"  # Public IP or hostname
      # Optional: Override default user for this specific node
      ansible_user: "avesha"
      # Optional: Private/internal IP for cluster communication
      private_ip: "10.0.102.57"
```

### Privilege Escalation Configuration

#### Option 1: Non-root user with sudo (Recommended)
```yaml
control_plane_nodes:
  - name: master-k8s
    ansible_host: "89.169.114.118"
    ansible_user: "avesha"           # Non-root user
    ansible_become: true             # Enable privilege escalation
    ansible_become_method: "sudo"    # Use sudo for escalation
    ansible_become_user: "root"      # Escalate to root user
    private_ip: "10.0.102.57"       # Internal IP (optional)
```

#### Option 2: Direct root access
```yaml
control_plane_nodes:
  - name: master-k8s
    ansible_host: "89.169.114.118"
    ansible_user: "root"             # Direct root access
    private_ip: "10.0.102.57"       # Internal IP (optional)
```

#### Option 3: Mixed configuration
```yaml
control_plane_nodes:
  - name: master-1
    ansible_host: "192.168.1.100"
    ansible_user: "ubuntu"
    ansible_become: true
    ansible_become_method: "sudo"
    ansible_become_user: "root"
    private_ip: "10.0.1.100"
    
  - name: master-2
    ansible_host: "192.168.1.101" 
    ansible_user: "root"             # This node uses direct root access
    private_ip: "10.0.1.101"

worker_nodes:
  - name: worker-1
    ansible_host: "192.168.1.200"
    ansible_user: "avesha"
    ansible_become: true
    ansible_become_method: "sudo"
    ansible_become_user: "root"
    private_ip: "10.0.1.200"
```

## Configuration Variables Explained

### Required Variables
- `name`: Unique identifier for the node
- `ansible_host`: IP address or hostname for SSH connection

### Optional Variables
- `ansible_user`: SSH user (defaults to `default_ansible_user`)
- `ansible_become`: Enable privilege escalation (true/false)
- `ansible_become_method`: Method for privilege escalation (sudo, su, pbrun, etc.)
- `ansible_become_user`: Target user for escalation (usually "root")
- `private_ip`: Internal IP address for cluster communication

## Prerequisites for Non-root Users

### 1. SSH Key Access
Ensure your SSH public key is in the user's `~/.ssh/authorized_keys`:
```bash
ssh-copy-id user@host
```

### 2. Sudo Configuration
The user must have sudo privileges. Add to `/etc/sudoers` or `/etc/sudoers.d/username`:
```bash
# For specific commands
username ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/systemctl

# For all commands (less secure but simpler)
username ALL=(ALL) NOPASSWD: ALL
```

### 3. Testing Configuration
Test your configuration:
```bash
# Test SSH access
ssh -i ~/.ssh/k8s_rsa user@host

# Test sudo access
ssh -i ~/.ssh/k8s_rsa user@host 'sudo whoami'
```

## Common Issues and Solutions

### Issue 1: SSH Key Authentication Fails
**Problem**: `Permission denied (publickey)`
**Solution**: 
1. Ensure SSH key is copied: `ssh-copy-id -i ~/.ssh/k8s_rsa.pub user@host`
2. Check key permissions: `chmod 600 ~/.ssh/k8s_rsa`
3. Verify SSH service allows key auth: `PubkeyAuthentication yes` in `/etc/ssh/sshd_config`

### Issue 2: Sudo Permission Denied
**Problem**: `sudo: password required`
**Solution**:
1. Add user to sudoers with NOPASSWD
2. Test: `ssh user@host 'sudo whoami'`

### Issue 3: Invalid Configuration
**Problem**: Ansible fails with privilege escalation errors
**Solution**:
1. Ensure all required fields are present
2. Use consistent indentation (2 spaces)
3. Validate YAML syntax

## Example Complete Configuration

```yaml
# user_input.yml
kubernetes_deployment:
  enabled: true
  
  # SSH Configuration
  ssh_key_path: "/home/user/.ssh/k8s_rsa"
  default_ansible_user: "avesha"
  
  # Control Plane Nodes
  control_plane_nodes:
    - name: master-k8s
      ansible_host: "89.169.114.118"    # Public IP
      ansible_user: "avesha"            # Non-root user
      ansible_become: true              # Enable sudo escalation
      ansible_become_method: "sudo"     # Use sudo
      ansible_become_user: "root"       # Escalate to root
      private_ip: "10.0.102.57"        # Private IP for cluster
      
  # Worker Nodes (if any)
  worker_nodes:
    - name: worker-1
      ansible_host: "89.169.114.119"
      ansible_user: "avesha"
      ansible_become: true
      ansible_become_method: "sudo"
      ansible_become_user: "root"
      private_ip: "10.0.102.58"
      
  # Kubernetes Configuration
  network_plugin: "calico"
  container_runtime: "containerd"
  dns_mode: "coredns"
```

## Validation Commands

Before running the deployment, validate your configuration:

```bash
# Test SSH connectivity
./deploy_smartscaler.sh --help

# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('user_input.yml'))"

# Test node accessibility
ansible all -i inventory/kubespray/inventory.ini -m ping
```

## Best Practices

1. **Use non-root users** with sudo for better security
2. **Test SSH access** before running deployment
3. **Use private IPs** for cluster communication when available
4. **Keep SSH keys secure** with proper permissions (600)
5. **Document your node setup** for troubleshooting
6. **Use consistent naming** for easier management 