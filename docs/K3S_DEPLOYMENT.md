# K3s Deployment Guide

This document describes how to deploy Kubernetes clusters using K3s via the [k3s-ansible](https://github.com/k3s-io/k3s-ansible) collection, which provides a lightweight alternative to kubespray.

## Overview

K3s is a lightweight Kubernetes distribution that is perfect for:
- Edge computing and IoT devices
- Development and testing environments
- Resource-constrained environments
- Single-node or small multi-node clusters

The K3s deployment feature integrates seamlessly with your existing `user_input.yml` configuration, allowing you to choose between kubespray (full Kubernetes) and K3s (lightweight Kubernetes) while maintaining the same configuration format.

## Prerequisites

- Ansible 8.0+ (ansible-core 2.15+)
- Python 3.6+
- SSH access to target nodes
- Target nodes running supported operating systems:
  - Debian/Ubuntu
  - RHEL/CentOS/Rocky Linux
  - SUSE/SLES
  - ArchLinux
  - Raspberry Pi OS

## Configuration

### 1. Enable K3s Deployment

In your `user_input.yml`, set the K3s deployment section:

```yaml
k3s_deployment:
  enabled: true                              # Enable K3s deployment
  
  # K3s Version Configuration
  k3s_version: "v1.28.0+k3s1"               # K3s version to install
  
  # K3s Configuration
  k3s_config:
    # Network Configuration
    service_cidr: "10.43.0.0/16"            # CIDR range for K3s services
    cluster_cidr: "10.42.0.0/16"            # CIDR range for K3s pods
    cluster_dns: "10.43.0.10"                # Cluster DNS service IP
    
    # CNI Configuration
    cni: "flannel"                           # CNI plugin (flannel, calico, cilium)
    
    # Additional K3s server arguments
    extra_server_args: ""                    # Additional arguments for K3s server
    
    # Additional K3s agent arguments
    extra_agent_args: ""                     # Additional arguments for K3s agents
    
    # External Database Configuration (for HA)
    use_external_database: false             # Use external database instead of embedded etcd
    datastore_endpoint: ""                   # External database endpoint (e.g., postgres://...)
    
    # Airgap Installation
    airgap_dir: ""                           # Path to airgap directory containing K3s binaries
    
    # SELinux Support
    selinux_enabled: false                   # Enable SELinux support
    
    # TLS Configuration
    tls_san: []                              # Additional TLS SANs for certificates
    
    # Node Labels
    node_labels: {}                           # Labels to apply to nodes
    
    # Node Taints
    node_taints: {}                           # Taints to apply to nodes
```

### 2. Node Configuration

K3s deployment uses the same node configuration as kubespray from the `kubernetes_deployment` section:

```yaml
kubernetes_deployment:
  # This section is required for K3s deployment
  # K3s will use the same node information
  control_plane_nodes:
    - name: "master-1"
      ansible_host: "192.168.1.10"
      ansible_user: "root"
      private_ip: "192.168.1.10"
      # ... other node configuration
  
  worker_nodes:
    - name: "worker-1"
      ansible_host: "192.168.1.11"
      ansible_user: "root"
      private_ip: "192.168.1.11"
      # ... other node configuration
```

## Deployment Methods

### Method 1: K3s Only Deployment

Deploy only a K3s cluster:

```bash
# 1. Setup K3s configuration
./setup_k3s.sh

# 2. Deploy K3s cluster
ansible-playbook k3s.yml
```

### Method 2: Full Deployment with K3s

Deploy K3s as part of the full Smart Scaler deployment:

```bash
# 1. Setup K3s configuration
./setup_k3s.sh

# 2. Deploy everything including K3s
ansible-playbook site.yml
```

### Method 3: Manual Deployment

Deploy manually after setup:

```bash
# 1. Setup K3s configuration
./setup_k3s.sh

# 2. Deploy manually using local repository
ansible-playbook -i inventory/k3s/inventory.yml k3s-ansible/playbooks/site.yml
```

## Setup Process

### 1. Run Setup Script

The `setup_k3s.sh` script will:

- Validate your configuration
- Clone the k3s-ansible repository locally
- Generate inventory files
- Create group_vars configuration
- Validate multi-master configurations
- Test SSH connectivity to all nodes
- Deploy the K3s cluster automatically

```bash
./setup_k3s.sh
```

### 2. Review Generated Files

The setup script generates:

- `inventory/k3s/inventory.yml` - K3s-specific inventory
- `inventory/k3s/group_vars/all.yml` - K3s configuration variables

### 3. Deploy Cluster

The setup script automatically deploys the cluster. If you want to deploy manually:

```bash
# Deploy using local repository
ansible-playbook -i inventory/k3s/inventory.yml k3s-ansible/playbooks/site.yml

# Or use the integrated playbook
ansible-playbook k3s.yml
```

## Configuration Options

### CNI Plugins

Supported CNI plugins:

- **flannel** (default) - Simple overlay network
- **calico** - Advanced networking with policy support
- **cilium** - eBPF-based networking with advanced features

### Multi-Master Configuration

For high availability with multiple control plane nodes:

```yaml
k3s_deployment:
  k3s_config:
    use_external_database: true
    datastore_endpoint: "postgres://user:pass@host:port/db"
```

**Important**: Multi-master K3s requires an external database and an odd number of control plane nodes.

### Airgap Installation

For environments without internet access:

```yaml
k3s_deployment:
  k3s_config:
    airgap_dir: "./k3s-airgap"
```

Place the following files in your airgap directory:
- `k3s` - K3s binary
- `k3s-airgap-images-<arch>.tar.gz` - Container images
- `k3s-selinux-<arch>.rpm` - SELinux package (if needed)

### Custom Arguments

Add custom K3s arguments:

```yaml
k3s_deployment:
  k3s_config:
    extra_server_args: "--disable traefik --disable servicelb"
    extra_agent_args: "--node-label region=us-west"
```

## Post-Deployment

### 1. Access Your Cluster

```bash
# Export kubeconfig
export KUBECONFIG=$PWD/output/k3s-kubeconfig

# Verify cluster
kubectl get nodes
kubectl get pods -n kube-system
```

### 2. Install Smart Scaler Applications

After K3s deployment, you can install Smart Scaler applications:

```yaml
# In user_input.yml
global_kubeconfig: "./output/k3s-kubeconfig"
```

Then run:
```bash
ansible-playbook site.yml
```

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   - Verify SSH key path in `user_input.yml`
   - Ensure SSH key has correct permissions (600)
   - Test SSH connection manually

2. **K3s Installation Failed**
   - Check node has internet access (unless using airgap)
   - Verify Python 3 is available on target nodes
   - Check system requirements (swap disabled, firewalld disabled)

3. **Multi-Master Issues**
   - Ensure external database is configured
   - Verify odd number of control plane nodes
   - Check database connectivity

4. **CNI Issues**
   - Verify CNI plugin is supported
   - Check network configuration doesn't conflict with host networks
   - Ensure required ports are open

### Debug Mode

Enable verbose output:

```bash
ansible-playbook k3s.yml -vvv
```

### Check K3s Logs

On target nodes:

```bash
# Check K3s service logs
journalctl -u k3s -f

# Check K3s logs
tail -f /var/log/k3s/k3s.log
```

## Comparison: K3s vs Kubespray

| Feature | K3s | Kubespray |
|---------|-----|-----------|
| **Resource Usage** | Lightweight (~512MB RAM) | Full Kubernetes (~2GB+ RAM) |
| **Installation Time** | Fast (~5-10 minutes) | Slower (~15-30 minutes) |
| **Features** | Core Kubernetes + Rancher extras | Full Kubernetes ecosystem |
| **Use Cases** | Edge, IoT, Dev/Test, Small clusters | Production, Enterprise, Large clusters |
| **Configuration** | Simple, opinionated | Flexible, customizable |
| **Maintenance** | Low maintenance | Standard Kubernetes maintenance |

## Best Practices

1. **Single Master**: Use K3s for development, testing, and small production clusters
2. **Multi-Master**: Use K3s with external database for HA production clusters
3. **Resource Constraints**: Choose K3s for edge devices and resource-limited environments
4. **Production**: Consider kubespray for large-scale production deployments
5. **Hybrid**: Use both - K3s for edge/dev and kubespray for core production

## Support

For K3s-specific issues:
- [K3s Documentation](https://docs.k3s.io/)
- [k3s-ansible Repository](https://github.com/k3s-io/k3s-ansible)
- [K3s GitHub Issues](https://github.com/k3s-io/k3s/issues)

For Smart Scaler integration issues:
- Check the generated configuration files
- Review the setup script output
- Enable verbose Ansible output for debugging
