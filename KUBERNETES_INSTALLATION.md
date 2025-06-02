# Kubernetes Cluster Installation Guide

This guide provides step-by-step instructions for setting up a Kubernetes cluster using Ansible-based automation scripts.

## Prerequisites

### System Requirements for smartscaler

#### Control Plane Nodes (Master)
- CPU: 8 cores minimum
- RAM: 16GB minimum
- Storage: 500GB minimum
- Operating System: Ubuntu 22.04+ or compatible Linux distribution

#### Worker Nodes
- CPU: 8 cores minimum
- RAM: 16GB minimum
- Storage: 500GB minimum
- Operating System: Same as control plane nodes

### Software Requirements

1. **Local Machine (Deployment Host)**
   ```bash
   # Install Python 3.x and pip
   sudo apt update
   sudo apt install -y python3 python3-pip python3-venv

   # Install SSH client
   sudo apt install -y openssh-client
   ```

2. **All Kubernetes Nodes**
   ```bash
   # Install SSH server
   sudo apt install -y openssh-server
   
   # Enable and start SSH service
   sudo systemctl enable ssh
   sudo systemctl start ssh
   ```

## Installation Steps

### 1. Initial Setup

1. **Clone the Repository**
   ```bash
   git clone <repository-url>
   cd smartscaler-apps-installer
   ```

2. **Setup Python Environment**
   ```bash
   # Create and activate virtual environment
   python3 -m venv venv
   source venv/bin/activate

   # Install dependencies
   pip install -r requirements.txt
   
   # Install Ansible collections
   ansible-galaxy install -r requirements.yml
   ```

3. **SSH Key Setup**
   ```bash
   # Generate SSH key
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/k8s_rsa -N ""

   # Copy SSH key to each node (repeat for each node)
   ssh-copy-id -i ~/.ssh/k8s_rsa.pub user@node-ip
   ```

### 2. Configuration

1. **Create/Edit user_input.yml**
   ```yaml
   kubernetes_deployment:
     enabled: true
     ssh_key_path: "~/.ssh/k8s_rsa"  # Path to your SSH private key
     default_ansible_user: "avesha"   # SSH user with sudo privileges
     control_plane_nodes:
       - name: "master1"
         ansible_host: "192.168.1.10"
       - name: "master2"
         ansible_host: "192.168.1.11"
       - name: "master3"
         ansible_host: "192.168.1.12"
     worker_nodes:
       - name: "worker1"
         ansible_host: "192.168.1.20"
       - name: "worker2"
         ansible_host: "192.168.1.21"
   ```

2. **Verify Configuration**
   ```bash
   # Check if all required files exist
   ls -l kubernetes.yml user_input.yml setup_kubernetes.sh
   ```

### 3. Deployment

1. **Run Installation Script**
   ```bash
   # Make script executable
   chmod +x setup_kubernetes.sh

   # Execute the script
   ./setup_kubernetes.sh
   ```

2. **Monitor Installation**
   - Watch the console output for progress
   - Check `ansible.log` for detailed logs
   - Installation typically takes 15-30 minutes

### 4. Post-Installation

1. **Verify Cluster Status**
   ```bash
   # On the first control plane node
   kubectl get nodes
   kubectl get pods -A
   ```

2. **Access Cluster**
   ```bash
   # Copy kubeconfig from master node
   scp -i ~/.ssh/k8s_rsa user@master1:/etc/kubernetes/admin.conf ~/.kube/config
   ```

## Network Requirements

### Required Open Ports

#### Control Plane Nodes
- TCP 6443: Kubernetes API server
- TCP 2379-2380: etcd server client API
- TCP 10250: Kubelet API
- TCP 10259: kube-scheduler
- TCP 10257: kube-controller-manager

#### Worker Nodes
- TCP 10250: Kubelet API
- TCP 30000-32767: NodePort Services

## Troubleshooting

### Common Issues

1. **SSH Connection Failures**
   ```bash
   # Check SSH connectivity
   ssh -i ~/.ssh/k8s_rsa -v user@node-ip
   ```

2. **Node Not Ready Status**
   ```bash
   # Check node status
   kubectl describe node <node-name>
   
   # Check system logs
   journalctl -xeu kubelet
   ```

3. **Pod Network Issues**
   ```bash
   # Check CNI pods
   kubectl get pods -n kube-system
   ```

### Logs Location
- Ansible logs: `ansible.log`
- Kubernetes logs: `/var/log/kubernetes/`
- System logs: `journalctl`

## Security Considerations

1. **SSH Security**
   - Use strong SSH keys
   - Restrict SSH access to specific IPs
   - Regular key rotation

2. **Network Security**
   - Implement network policies
   - Use private network for cluster communication
   - Enable firewall rules

3. **Access Control**
   - Use RBAC policies
   - Implement least privilege principle
   - Regular audit of access permissions

## SSH User Configuration

### Default Configuration
The default configuration uses:
- SSH User: `avesha`
- Privilege Escalation: Using `sudo` to `root`
- Location: Configured in `user_input.yml`

### User Options
You can configure the SSH access in two ways:

1. **Default (Recommended)**: Using non-root user with sudo
   ```yaml
   ansible_user: avesha
   ansible_become: true
   ansible_become_method: sudo
   ansible_become_user: root
   ```
   This is the more secure approach as it:
   - Follows security best practices
   - Provides audit trail for privileged actions
   - Reduces risk of accidental system-wide changes

2. **Alternative**: Direct root access
   ```yaml
   ansible_user: root
   ```
   While simpler, this is not recommended for production environments.

### Important Notes
- The default `avesha` user must have sudo privileges
- No password prompt for sudo (NOPASSWD in sudoers)
- SSH key-based authentication is required
- The user must have access to `/etc/kubernetes` and other system directories

### Troubleshooting SSH Access
If you encounter permission issues:
1. Verify sudo privileges: `sudo -l`
2. Check SSH key permissions
3. Ensure sudoers configuration is correct
4. Test SSH connection: `ssh -i ~/.ssh/k8s_rsa -v avesha@node-ip`

## Support

For issues and support:
1. Check the troubleshooting guide above
2. Review `ansible.log` for detailed error messages
3. Contact support team with relevant logs and error messages

## Maintenance

### Regular Tasks
1. Update system packages
2. Backup etcd data
3. Monitor cluster health
4. Review security policies

### Upgrade Process
Refer to the upgrade documentation for version-specific instructions.

## Kubeconfig File Handling

The deployment process automatically retrieves the kubeconfig file from the first control plane node. This involves:

1. Using sudo to read `/etc/kubernetes/admin.conf` on the control plane node
2. Securely copying the file to the local machine
3. Setting appropriate permissions (600) on the local copy

The kubeconfig file will be saved to `files/kubeconfig` in the installer directory.

### Configuration in user_input.yml
```yaml
kubernetes_deployment:
  enabled: true
  ssh_key_path: "~/.ssh/k8s_rsa"  # Path to your SSH private key
  default_ansible_user: "avesha"   # SSH user with sudo privileges
  control_plane_nodes:
    - name: "master1"
      ansible_host: "192.168.1.10"
    # ... other nodes ...
```

### Manual Retrieval
If you need to manually retrieve the kubeconfig file, you can use:

```bash
# Using configured user (recommended)
SSH_KEY="~/.ssh/k8s_rsa"  # Use your SSH key path
SSH_USER="avesha"         # Use your configured user
MASTER_IP="192.168.1.10"  # Use your master node IP

ssh -i "$SSH_KEY" "$SSH_USER@$MASTER_IP" 'sudo cat /etc/kubernetes/admin.conf' > kubeconfig
chmod 600 kubeconfig
``` 
