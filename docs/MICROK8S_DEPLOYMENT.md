# MicroK8s Deployment Guide

This document describes how to deploy Kubernetes clusters using MicroK8s via Ansible, providing a snap-based alternative for ARM Ubuntu systems.

## Overview

MicroK8s is a lightweight, certified Kubernetes distribution that is perfect for:
- Edge computing and IoT devices
- Development and testing environments  
- ARM-based systems (including Jetson devices)
- Cloud instances and on-premises deployments
- Single-node or small multi-node clusters

The MicroK8s deployment feature integrates seamlessly with your existing `user_input.yml` configuration, using the same node configuration as kubespray while providing MicroK8s-specific settings.

## Prerequisites

### System Requirements
- Ansible 8.0+ (ansible-core 2.15+)
- Python 3.6+
- SSH access to target nodes
- Target nodes running Ubuntu 18.04+ (ARM64 or AMD64)
- Snap support on target systems
- At least 2GB RAM per node
- At least 20GB storage per node

### Ansible Collections
The following Ansible collection is required:
```bash
ansible-galaxy collection install community.general
```

### Supported Architectures
- ARM64 (aarch64) - Including NVIDIA Jetson devices
- AMD64 (x86_64)

## Configuration

### 1. Enable MicroK8s Deployment

In your `user_input.yml`, set the MicroK8s deployment section:

```yaml
microk8s_deployment:
  enabled: true                              # Enable MicroK8s deployment
  
  # MicroK8s Version Configuration
  microk8s_channel: "latest/stable"          # MicroK8s snap channel
  
  # MicroK8s Configuration
  microk8s_config:
    # Essential add-ons to enable by default
    addons:
      - dns                                   # CoreDNS for cluster DNS
      - storage                               # Local path storage provisioner
      - ingress                               # NGINX ingress controller
    
    # Additional optional add-ons
    additional_addons: []
    # Examples:
    # additional_addons:
    #   - dashboard                           # Kubernetes dashboard
    #   - metrics-server                      # Metrics server
    #   - prometheus                          # Prometheus monitoring
    #   - gpu                                 # GPU support for NVIDIA devices
    
    # Multi-node cluster configuration
    cluster_setup:
      enable_clustering: true                 # Enable multi-node clustering
      join_timeout: 300                       # Timeout for nodes to join
    
    # Network Configuration (MicroK8s defaults)
    network:
      service_cidr: "10.152.183.0/24"        # CIDR range for services
      pod_cidr: "10.1.0.0/16"                # CIDR range for pods
      api_port: 16443                         # MicroK8s API server port
    
    # Container Configuration
    container_runtime:
      enable_nvidia_support: true             # Enable NVIDIA GPU support
      configure_registry: false               # Configure private registry
    
    # High Availability Configuration
    ha_config:
      enable_ha: false                        # Enable HA mode (requires 3+ nodes)
      datastore: "dqlite"                     # Datastore type for HA
```

### 2. Node Configuration

MicroK8s deployment reuses the same node configuration from the `kubernetes_deployment` section:

```yaml
kubernetes_deployment:
  # SSH Access Configuration
  ssh_key_path: "/path/to/your/ssh/key"
  default_ansible_user: "ubuntu"

  # Control Plane Node Configuration
  control_plane_nodes:
    - name: "microk8s-master-1"
      ansible_host: "192.168.1.100"
      ansible_user: "ubuntu"
      private_ip: "192.168.1.100"
    # Add more nodes for multi-node clusters

  # Worker Node Configuration (Optional)
  worker_nodes:
    - name: "microk8s-worker-1"
      ansible_host: "192.168.1.101"
      ansible_user: "ubuntu"
      private_ip: "192.168.1.101"
```

## Deployment

### 1. Using the Setup Script

The easiest way to deploy MicroK8s is using the provided setup script:

```bash
./setup_microk8s.sh
```

This script will:
- Validate configuration
- Generate inventory files
- Test SSH connectivity
- Install required Ansible collections
- Execute the MicroK8s deployment

### 2. Manual Deployment

Alternatively, you can deploy manually:

```bash
# Generate configuration files
python3 files/microk8s/generate_microk8s_config.py

# Test SSH connectivity
python3 files/microk8s/test_ssh_connectivity.py

# Run Ansible playbook
ansible-playbook microk8s.yml
```

### 3. MicroK8s-Only Deployment

To deploy only MicroK8s without Smart Scaler applications:

```bash
# Using setup script
./setup_microk8s.sh

# Or using playbook directly
ansible-playbook microk8s.yml
```

## Available Add-ons

### Essential Add-ons (Enabled by Default)
- **dns**: CoreDNS for cluster DNS resolution
- **storage**: Local path storage provisioner
- **ingress**: NGINX ingress controller

### Optional Add-ons
- **dashboard**: Kubernetes web dashboard
- **metrics-server**: Resource metrics API
- **prometheus**: Prometheus monitoring stack
- **cert-manager**: Certificate management
- **istio**: Service mesh
- **knative**: Serverless platform
- **gpu**: NVIDIA GPU support
- **metallb**: Load balancer for bare metal
- **registry**: Private container registry

### Enabling Additional Add-ons

Add desired add-ons to your configuration:

```yaml
microk8s_config:
  additional_addons:
    - dashboard
    - metrics-server
    - prometheus
    - gpu  # For NVIDIA GPU support
```

## Multi-Node Clustering

### Automatic Clustering

When multiple nodes are defined in your configuration, MicroK8s will automatically:
1. Install MicroK8s on all nodes
2. Configure the first node as the primary
3. Generate join tokens on the primary node
4. Join additional nodes to the cluster

### Manual Cluster Operations

After deployment, you can manually manage the cluster:

```bash
# On the primary node - generate join token
microk8s add-node

# On worker nodes - join the cluster
microk8s join <join-token>

# View cluster status
microk8s status
microk8s kubectl get nodes
```

## High Availability

### HA Configuration

For production deployments with high availability:

```yaml
microk8s_config:
  ha_config:
    enable_ha: true
    datastore: "dqlite"
```

### Requirements for HA
- Minimum 3 control plane nodes (odd numbers recommended)
- Reliable network connectivity between nodes
- Synchronized time (NTP recommended)

## NVIDIA GPU Support

### Automatic GPU Detection

The deployment automatically detects and configures NVIDIA GPUs:

1. **Jetson Prerequisites**: Detects Jetson devices and installs jetson-stats
2. **NVIDIA Prerequisites**: Detects NVIDIA GPUs and configures container runtime
3. **GPU Add-on**: Enables MicroK8s GPU add-on if GPUs are detected

### Manual GPU Configuration

To explicitly enable GPU support:

```yaml
microk8s_config:
  container_runtime:
    enable_nvidia_support: true
  additional_addons:
    - gpu
```

### Testing GPU Support

After deployment, test GPU functionality:

```bash
# Check GPU add-on status
microk8s status

# Test GPU pod
microk8s kubectl run gpu-test --image=nvidia/cuda:11.0-base --rm -it --restart=Never -- nvidia-smi
```

## Network Configuration

### Default Network Settings

MicroK8s uses the following default network configuration:

- **Service CIDR**: `10.152.183.0/24`
- **Pod CIDR**: `10.1.0.0/16`
- **API Port**: `16443`
- **CNI**: Calico (default in MicroK8s)

### Custom Network Configuration

To customize network settings:

```yaml
microk8s_config:
  network:
    service_cidr: "10.152.183.0/24"
    pod_cidr: "10.1.0.0/16"
    api_port: 16443
```

### Firewall Configuration

Ensure the following ports are open:

- **16443/tcp**: MicroK8s API server
- **10250/tcp**: Kubelet API
- **10255/tcp**: Kubelet readonly API (optional)
- **25000/tcp**: MicroK8s cluster agent
- **8472/udp**: Flannel VXLAN (if using Flannel)

## Storage

### Default Storage

MicroK8s includes a local path storage provisioner:

- **Storage Class**: `microk8s-hostpath`
- **Provisioner**: Local path on each node
- **Reclaim Policy**: Delete

### Custom Storage

For production deployments, consider:

```yaml
microk8s_config:
  additional_addons:
    - metallb      # For LoadBalancer services
    - registry     # For private container registry
```

## Verification

### Cluster Health

After deployment, verify cluster health:

```bash
# Export kubeconfig
export KUBECONFIG=$PWD/output/kubeconfig

# Check cluster info
kubectl cluster-info

# Check nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Check add-on status
microk8s status  # Run on cluster nodes
```

### Testing Deployments

Test basic functionality:

```bash
# Create test deployment
kubectl create deployment nginx --image=nginx

# Expose deployment
kubectl expose deployment nginx --port=80 --type=NodePort

# Check deployment
kubectl get deployments,services,pods
```

## Troubleshooting

### Common Issues

#### 1. Snap Installation Failures
```bash
# Check snap service
sudo systemctl status snapd

# Refresh snap core
sudo snap refresh core

# Check snap channels
snap info microk8s
```

#### 2. Node Join Failures
```bash
# Check cluster status on primary node
microk8s status

# Regenerate join token
microk8s add-node

# Check network connectivity
ping <primary-node-ip>
telnet <primary-node-ip> 25000
```

#### 3. Add-on Failures
```bash
# Check add-on status
microk8s status

# View add-on logs
microk8s kubectl logs -n kube-system <pod-name>

# Disable and re-enable add-on
microk8s disable <addon>
microk8s enable <addon>
```

#### 4. GPU Support Issues
```bash
# Check NVIDIA driver
nvidia-smi

# Check containerd configuration
sudo cat /var/snap/microk8s/current/args/containerd

# Check GPU add-on
microk8s kubectl get nodes -o json | jq '.items[].status.allocatable'
```

### Log Locations

- **Ansible logs**: `output/ansible.log`
- **MicroK8s logs**: `sudo journalctl -u snap.microk8s.*`
- **Kubelet logs**: `microk8s kubectl logs -n kube-system -l app=kubelet`

### Support Resources

- [MicroK8s Documentation](https://microk8s.io/docs)
- [MicroK8s GitHub](https://github.com/canonical/microk8s)
- [Ubuntu MicroK8s Tutorial](https://ubuntu.com/tutorials/install-a-local-kubernetes-with-microk8s)

## Migration from K3s

### Key Differences

| Feature | K3s | MicroK8s |
|---------|-----|-----------|
| Installation | Binary | Snap |
| CNI | Flannel (default) | Calico (default) |
| API Port | 6443 | 16443 |
| Service CIDR | 10.43.0.0/16 | 10.152.183.0/24 |
| Add-ons | Limited | Extensive |
| HA Datastore | etcd/external | dqlite |

### Migration Steps

1. **Backup applications**: Export manifests from K3s cluster
2. **Update configuration**: Change deployment type in `user_input.yml`
3. **Deploy MicroK8s**: Run `./setup_microk8s.sh`
4. **Restore applications**: Apply exported manifests to MicroK8s cluster

## Best Practices

### Production Deployments

1. **Use specific channels**: Pin to stable channels (e.g., `1.32/stable`)
2. **Enable HA**: Use 3+ control plane nodes
3. **Resource limits**: Set appropriate resource limits
4. **Monitoring**: Enable metrics-server and prometheus add-ons
5. **Backup**: Implement backup strategies for persistent data

### Security

1. **Network policies**: Implement network segmentation
2. **RBAC**: Configure role-based access control
3. **Pod security**: Enable pod security standards
4. **Image security**: Use trusted container registries

### Performance

1. **Node sizing**: Ensure adequate resources per node
2. **Storage**: Use fast storage for critical workloads
3. **Network**: Ensure low-latency network between nodes
4. **Monitoring**: Monitor resource usage and performance metrics

## Advanced Configuration

### Custom Registries

```yaml
microk8s_config:
  container_runtime:
    configure_registry: true
    # Additional registry configuration can be added
```

### Custom CNI

While MicroK8s uses Calico by default, you can customize networking:

```bash
# After deployment, configure custom CNI if needed
microk8s kubectl apply -f custom-cni.yaml
```

### Integration with CI/CD

MicroK8s can be integrated with CI/CD pipelines:

```bash
# In CI/CD scripts
export KUBECONFIG=/path/to/kubeconfig
kubectl apply -f deployment.yaml
```

This completes the comprehensive MicroK8s deployment guide. The system provides a robust, lightweight Kubernetes solution specifically optimized for ARM systems and edge computing scenarios.
