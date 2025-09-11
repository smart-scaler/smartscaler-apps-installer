# MicroK8s Deployment Guide

## Overview

Step-by-step instructions for deploying MicroK8s (single-node or multi-node) using the smartscaler-apps-installer. Features automated external access setup, TLS certificates, and AWS security group configuration.

**Key Features**: External access, multi-node clustering, GPU support, ARM64 compatibility, one-command deployment.

## Prerequisites

- **Remote machine(s)**: Ubuntu 20.04+, 4GB+ RAM, 20GB+ storage
- **SSH access**: Key-based authentication with sudo privileges  
- **Public IP**: For external Kubernetes API access
- **Local machine**: Python 3, Ansible

## 🌐 Networking Requirements & AWS Security Group Configuration

### Single-Node Setup

For single-node deployments, you only need:

| Port | Protocol | Purpose | Source |
|------|----------|---------|--------|
| **16443** | TCP | Kubernetes API Server | 0.0.0.0/0 (external access) |
| **22** | TCP | SSH access | Your local IP |

#### AWS Security Group Commands (Single-Node)
```bash
# Get your security group ID
SECURITY_GROUP_ID="sg-your-security-group-id"

# Allow API server access from anywhere
aws ec2 authorize-security-group-ingress \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 16443 \
  --cidr 0.0.0.0/0

# Allow SSH from your IP (replace with your actual IP)
aws ec2 authorize-security-group-ingress \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_IP/32
```

### Multi-Node Setup

Multi-node MicroK8s clusters require additional ports for internal communication:

| Port | Protocol | Purpose | Required Between |
|------|----------|---------|------------------|
| **16443** | TCP | Kubernetes API Server | External → Master |
| **25000** | TCP | dqlite database (clustering) | Master ↔ Workers |
| **19001** | TCP | dqlite raft protocol | Master ↔ Workers |
| **10250** | TCP | kubelet API | Master ↔ Workers |
| **10256** | TCP | kube-proxy health check | Master ↔ Workers |
| **22** | TCP | SSH access | Local → All nodes |

#### AWS Security Group Commands (Multi-Node)
```bash
SECURITY_GROUP_ID="sg-your-security-group-id"

# API server access from external
aws ec2 authorize-security-group-ingress \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 16443 \
  --cidr 0.0.0.0/0

# Clustering ports (between instances in same security group)
for PORT in 25000 19001 10250 10256; do
  aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port $PORT \
    --source-group $SECURITY_GROUP_ID
done

# SSH access (replace with your IP)
aws ec2 authorize-security-group-ingress \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_IP/32
```

#### Manual AWS Console Configuration
1. Go to **AWS EC2 Console** → **Security Groups**
2. Find your security group and click **Edit inbound rules**
3. Add the following rules:

**For Single-Node:**
- Type: Custom TCP, Port: 16443, Source: 0.0.0.0/0
- Type: SSH, Port: 22, Source: Your IP

**For Multi-Node (add these to single-node rules):**
- Type: Custom TCP, Port: 25000, Source: sg-your-security-group-id
- Type: Custom TCP, Port: 19001, Source: sg-your-security-group-id  
- Type: Custom TCP, Port: 10250, Source: sg-your-security-group-id
- Type: Custom TCP, Port: 10256, Source: sg-your-security-group-id

> **⚠️ Critical**: For multi-node deployments, ensure all ports are open **before** running Ansible. Test connectivity with `telnet <master-private-ip> 25000` from worker nodes.

### Network Verification
```bash
# Test connectivity (from worker to master)
telnet <master-private-ip> 25000
```

## 🚀 Deployment Instructions

### Step 1: Local Setup

```bash
# Clone and setup
git clone https://github.com/smart-scaler/smartscaler-apps-installer.git
cd smartscaler-apps-installer && git checkout microk8s-setup-david
python3 -m venv venv && source venv/bin/activate && pip install ansible

# Setup SSH keys (adjust paths based on your local_environment.ssh_key_directory)
ssh-keygen -t rsa -b 4096 -f /your/project/base/path/microk8s_key -N ""
ssh-copy-id -i /your/project/base/path/microk8s_key.pub ubuntu@<node-ip>
```

### Step 2: Configure user_input.yml

**First, configure your local environment paths:**

1. **Edit the `local_environment` section** in `user_input.yml`:
   ```yaml
   local_environment:
     project_root: "/your/absolute/path/to/project"  # Update this path!
     workspace_root: "."
     output_directory: "output" 
     venv_directory: "venv"
     ssh_key_directory: "{{ local_environment.project_root }}"
   ```

2. **Replace `/your/absolute/path/to/project`** with your actual project directory path

#### Single-Node Configuration
```yaml
microk8s_deployment:
  enabled: true
  api_server:
    host: "YOUR_MASTER_PUBLIC_IP"
    port: 16443
    bind_address: "0.0.0.0"
  ssh_key_path: "{{ local_environment.ssh_key_directory }}/microk8s_key"
  default_ansible_user: "ubuntu"
  control_plane_nodes:
    - name: "microk8s-master-1"
      ansible_host: "YOUR_MASTER_PUBLIC_IP"
      ansible_user: "ubuntu"
      ansible_become: true
      private_ip: "MASTER_PRIVATE_IP"
      node_role: "primary-master"
  worker_nodes: []  # Empty for single-node

# Global settings  
global_control_plane_ip: "YOUR_MASTER_PUBLIC_IP"
global_kubeconfig: "output/kubeconfig"
global_kubecontext: "microk8s"

# Local Environment Paths (configure for your system)
local_environment:
  project_root: "/your/project/base/path"  # Full path to your project directory
  workspace_root: "."
  output_directory: "output"
  venv_directory: "venv" 
  ssh_key_directory: "{{ local_environment.project_root }}"
```

#### Multi-Node Configuration
```yaml
microk8s_deployment:
  enabled: true
  api_server:
    host: "MASTER_PUBLIC_IP"
    port: 16443
    bind_address: "0.0.0.0"
  ssh_key_path: "{{ local_environment.ssh_key_directory }}/microk8s_key"
  default_ansible_user: "ubuntu"
  control_plane_nodes:
    - name: "microk8s-master-1"
      ansible_host: "MASTER_PUBLIC_IP"
      ansible_user: "ubuntu"
      ansible_become: true
      private_ip: "MASTER_PRIVATE_IP"
      node_role: "primary-master"
  worker_nodes:
    - name: "microk8s-worker-1"
      ansible_host: "WORKER1_PUBLIC_IP"
      ansible_user: "ubuntu"
      ansible_become: true
      private_ip: "WORKER1_PRIVATE_IP"
      node_role: "worker"
    # Add more workers as needed

# Global settings
global_control_plane_ip: "MASTER_PUBLIC_IP"
global_kubeconfig: "output/kubeconfig"
global_kubecontext: "microk8s"

# Local Environment Paths (configure for your system)
local_environment:
  project_root: "/your/project/base/path"
  workspace_root: "."
  output_directory: "output"
  venv_directory: "venv"
  ssh_key_directory: "{{ local_environment.project_root }}"
```

### Step 3: Deploy

```bash
ansible-playbook microk8s.yml -v
```

**Automated process**: Prerequisites validation → MicroK8s installation → External access configuration → TLS certificate setup → Cluster joining (multi-node) → Add-on enablement → Health validation

## Verification

```bash
# Use generated kubeconfig
export KUBECONFIG=$PWD/output/kubeconfig

# Verify cluster
kubectl get nodes -o wide
kubectl get pods --all-namespaces
kubectl cluster-info

# Test API access
curl -k https://YOUR_MASTER_PUBLIC_IP:16443/version

# Multi-node: Test pod distribution
kubectl run test-nginx --image=nginx --replicas=3
kubectl get pods -o wide
kubectl delete deployment test-nginx
```

## Configuration Options

**Default add-ons**: dns, storage, ingress  
**Optional add-ons**: dashboard, metrics-server, prometheus, cert-manager, gpu

```yaml
# GPU support
microk8s_config:
  container_runtime:
    enable_nvidia_support: true
```

## Troubleshooting

**SSH Issues**:
```bash
# Fix permissions and test
chmod 600 ~/.ssh/microk8s_key
ssh -i ~/.ssh/microk8s_key ubuntu@YOUR_PUBLIC_IP
```

**API Connection Refused**: Check security group port 16443, verify `microk8s status`

**Multi-node Join Failures**:
```bash
# Test connectivity from worker to master
telnet <master-private-ip> 25000  # Must connect immediately
# Check security group allows ports 25000, 19001, 10250, 10256
```

**External Access Issues**: Verify kubeconfig server URL matches public IP

**Diagnostic Commands**:
```bash
microk8s status && microk8s inspect
kubectl get events --sort-by='.lastTimestamp'
sudo journalctl -u snap.microk8s.*
```

## Scaling

**Add Worker**: Launch instance, configure SSH, add to `user_input.yml`, re-run `ansible-playbook microk8s.yml`

**Remove Worker**: 
```bash
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
kubectl delete node <node-name>
```

## Success Indicators

- ✅ `kubectl get nodes` shows "Ready" state
- ✅ External API access works  
- ✅ System pods running
- ✅ Multi-node: Pods distributed across nodes

## Next Steps

Deploy applications, configure monitoring, set up ingress, install Smart Scaler apps.

**Resources**: [MicroK8s Docs](https://microk8s.io/docs) | [Smart Scaler Repo](https://github.com/smart-scaler/smartscaler-apps-installer)

---

## Quick Reference

**Essential Commands**:
```bash
kubectl get nodes && kubectl get pods --all-namespaces
microk8s status && microk8s inspect  
kubectl get events --sort-by='.lastTimestamp'
```

**Files**: Kubeconfig: `output/kubeconfig` | MicroK8s config: `/var/snap/microk8s/current/`
