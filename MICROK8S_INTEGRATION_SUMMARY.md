# MicroK8s Installation Guide

## Overview

This guide provides simple step-by-step instructions for installing MicroK8s using the smartscaler-apps-installer. MicroK8s is a lightweight Kubernetes distribution perfect for edge computing, development, and production workloads.

## ✨ Key Features

- **🌐 External Access**: Automatic configuration for public IP access with TLS certificates
- **🏗️ Multi-Node Support**: Single-node or multi-node cluster deployment
- **🔧 Global Variables**: Consistent configuration with k8s and k3s deployments
- **🚀 Automated Setup**: One-command deployment with intelligent configuration
- **🖥️ ARM64 Support**: Optimized for ARM-based systems including NVIDIA Jetson
- **🎮 GPU Support**: Automatic NVIDIA GPU detection and configuration
- **📦 Snap-based**: Easy installation and management via snap packages

## 📋 Prerequisites

- **Remote machine(s)** with Ubuntu 20.04+ (ARM64 or AMD64)
- **SSH access** with root privileges
- **Public IP address** for external access
- **Port 16443** open in firewall/security group

## 🚀 Installation Steps

### Step 1: SSH Access Setup

```bash
# SSH into your primary machine
ssh root@44.211.118.140

# Generate SSH key if it doesn't exist
ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ""

# Add the public key to authorized_keys for local Ansible access
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
chmod 700 /root/.ssh
```

### Step 2: Repository and Environment Setup

```bash
# Clone the repository
git clone https://github.com/smart-scaler/smartscaler-apps-installer.git
cd smartscaler-apps-installer

# Switch to the MicroK8s branch
git checkout microk8s-setup-david

# Create and activate Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Ansible
pip install ansible
```

### Step 3: Configure Deployment

Edit `user_input.yml` to configure your deployment:

#### 📍 Single-Node Configuration

```yaml
microk8s_deployment:
  enabled: true
  
  # API Server Configuration
  api_server:
    host: "44.211.118.140"        # Your public IP
    port: 16443
    bind_address: "0.0.0.0"
    secure: true

  # SSH Configuration
  ssh_key_path: "/root/.ssh/id_rsa"
  default_ansible_user: "root"

  # Single Node Configuration
  control_plane_nodes:
    - name: "microk8s-master-1"
      ansible_host: "44.211.118.140"  # Your public IP
      ansible_user: "root"
      ansible_become: true
      ansible_become_method: "sudo"
      ansible_become_user: "root"
      private_ip: "10.0.102.254"      # Your private IP
      node_role: "primary-master"

  # No worker nodes for single-node setup
  worker_nodes: []
```

#### 🏗️ Multi-Node Configuration

```yaml
microk8s_deployment:
  enabled: true
  
  # API Server Configuration
  api_server:
    host: "44.211.118.140"        # Primary master public IP
    port: 16443
    bind_address: "0.0.0.0"
    secure: true

  # SSH Configuration
  ssh_key_path: "/root/.ssh/id_rsa"
  default_ansible_user: "root"

  # Primary Master Node
  control_plane_nodes:
    - name: "microk8s-master-1"
      ansible_host: "44.211.118.140"  # Master public IP
      ansible_user: "root"
      ansible_become: true
      ansible_become_method: "sudo"
      ansible_become_user: "root"
      private_ip: "10.0.102.254"      # Master private IP
      node_role: "primary-master"

  # Worker Nodes
  worker_nodes:
    - name: "microk8s-worker-1"
      ansible_host: "WORKER_1_PUBLIC_IP"  # Replace with actual IP
      ansible_user: "root"
      ansible_become: true
      ansible_become_method: "sudo"
      ansible_become_user: "root"
      private_ip: "10.0.102.11"         # Worker private IP
      node_role: "worker"
    # Add more worker nodes as needed
```

#### 🌐 Global Configuration

Also ensure these global settings are configured:

```yaml
# Required Global Settings
global_control_plane_ip: "44.211.118.140"    # Primary master public IP
global_kubeconfig: "output/kubeconfig"        # Kubeconfig output path
global_kubecontext: "default"                 # Kubernetes context
use_global_context: true                      # Use global context
```

### Step 4: Deploy MicroK8s

```bash
# Run the automated deployment
ansible-playbook microk8s.yml
```

**What this does automatically:**
- ✅ Validates prerequisites and installs missing tools (kubectl, helm)
- ✅ Generates dynamic inventory from your configuration
- ✅ Installs MicroK8s on all specified nodes
- ✅ Configures API server for external access (0.0.0.0 binding)
- ✅ Adds public IP to TLS certificate Subject Alternative Names
- ✅ Sets up multi-node cluster joining (if applicable)
- ✅ Enables essential add-ons (DNS, storage, ingress)
- ✅ Generates external kubeconfig with public IP
- ✅ Validates cluster health and connectivity

## 🎯 Post-Installation

### External Access Setup

#### Option 1: Copy kubeconfig to local machine
```bash
# From your local machine
scp root@44.211.118.140:/root/smartscaler-apps-installer/output/kubeconfig ~/.kube/microk8s-config

# Test external access
export KUBECONFIG=~/.kube/microk8s-config
kubectl get nodes
kubectl get pods --all-namespaces
```

#### Option 2: Use kubeconfig on remote machine
```bash
# On the remote machine
export KUBECONFIG=/root/smartscaler-apps-installer/output/kubeconfig
kubectl get nodes
```

### Verify Multi-Node Setup (if applicable)

```bash
# Check all nodes are joined and ready
kubectl get nodes -o wide

# Verify pods are distributed across nodes
kubectl get pods --all-namespaces -o wide

# Check cluster information
kubectl cluster-info
```

## 🔧 Configuration Options

### Essential Add-ons (enabled by default)
- `dns` - CoreDNS for cluster DNS
- `storage` - Local path storage provisioner  
- `ingress` - NGINX ingress controller

### Optional Add-ons
Add these to `microk8s_config.additional_addons` in `user_input.yml`:
- `dashboard` - Kubernetes dashboard
- `metrics-server` - Resource monitoring
- `prometheus` - Monitoring stack
- `cert-manager` - Certificate management
- `gpu` - NVIDIA GPU support (auto-detected)

### GPU Support
```yaml
microk8s_config:
  container_runtime:
    enable_nvidia_support: true  # Enable if you have NVIDIA GPUs
```

## 🐛 Troubleshooting

### Common Issues

**🔒 Connection refused on port 16443**
- Check firewall/security group allows port 16443
- Verify API server is binding to 0.0.0.0 (should be automatic)

**🔑 TLS certificate errors**
- Certificate SAN fix is now automated
- Should include your public IP automatically

**🖥️ SSH connectivity issues**
- Ensure SSH keys are properly configured in `/root/.ssh/`
- Verify `ssh_key_path` in `user_input.yml` is correct

**👥 Multi-node joining failures**
- Check network connectivity between nodes
- Verify all nodes can reach the primary master
- Review join logs in Ansible output

### Diagnostic Commands

```bash
# Check MicroK8s status
microk8s status

# View system logs
sudo journalctl -u snap.microk8s.*

# Check certificate details
openssl x509 -in /var/snap/microk8s/current/certs/server.crt -text -noout | grep -A 10 "Subject Alternative Name"

# Test API server connectivity
curl -k https://44.211.118.140:16443/version
```

## 📈 Scaling Your Cluster

### Adding Worker Nodes Later

1. **Add new node configuration** to `user_input.yml`:
   ```yaml
   worker_nodes:
     - name: "microk8s-worker-2"
       ansible_host: "NEW_WORKER_IP"
       # ... configuration
   ```

2. **Re-run the deployment**:
   ```bash
   ansible-playbook microk8s.yml
   ```

The system will automatically detect new nodes and join them to the existing cluster.

## 🏆 Success Criteria

Your MicroK8s installation is successful when:

- ✅ `kubectl get nodes` shows all nodes in "Ready" state
- ✅ External access works from your local machine
- ✅ System pods are running in kube-system namespace
- ✅ `kubectl cluster-info` shows accessible endpoints
- ✅ Multi-node clusters show proper node distribution

## 🎯 Next Steps

After successful installation:

1. **Deploy applications** using `kubectl` or Helm
2. **Configure additional add-ons** as needed
3. **Set up monitoring** with Prometheus (optional add-on)
4. **Configure ingress** for application access
5. **Install Smart Scaler apps** using `ansible-playbook site.yml`

Your MicroK8s cluster is now ready for production workloads with full external access and multi-node capabilities! 🚀

## 🆘 Support

- [MicroK8s Documentation](https://microk8s.io/docs)
- [Ubuntu MicroK8s Tutorial](https://ubuntu.com/tutorials/install-a-local-kubernetes-with-microk8s)
- [Smart Scaler Documentation](https://github.com/smart-scaler/smartscaler-apps-installer)