# Kubernetes Configuration

This document describes the Kubernetes cluster configuration options and deployment settings in our Ansible automation.

## ⚠️ Important: Installation Method

The **ONLY** supported method for installing Kubernetes is through the `setup_kubernetes.sh` script. This script handles all necessary setup steps and validations to ensure a proper cluster deployment.

## Script Functionality

The `setup_kubernetes.sh` script performs the following critical operations:

1. **Environment Validation**
   - Checks and sets up proper locale settings
   - Validates Python virtual environment
   - Verifies Kubernetes deployment is enabled in configuration

2. **Configuration Processing**
   - Reads node information from `user_input.yml`
   - Validates required configuration parameters
   - Generates Kubespray inventory automatically

3. **SSH Setup and Validation**
   - Tests SSH connectivity to all nodes
   - Verifies proper SSH key configuration
   - Ensures proper user permissions

4. **Node Configuration**
   - Sets up control plane nodes
   - Configures worker nodes
   - Handles node-specific user configurations

5. **Security Checks**
   - Validates SSH key permissions
   - Verifies user access rights
   - Ensures secure communication setup

6. **Deployment Preparation**
   - Generates necessary inventory files
   - Sets up required environment variables
   - Prepares Ansible configuration

## Configuration Structure

The Kubernetes configuration is managed through `user_input.yml`:

```yaml
kubernetes_deployment:
  # Basic cluster configuration
  kubeconfig_path: "/path/to/kubeconfig"
  kube_context: "your-context"
  default_ansible_user: "ubuntu"
  ssh_key_path: "/path/to/ssh/key"

  # Node configuration
  control_plane_nodes:
    - ansible_host: "192.168.1.10"
      ansible_user: "ubuntu"
      node_name: "master-1"
  worker_nodes:
    - ansible_host: "192.168.1.11"
      ansible_user: "ubuntu"
      node_name: "worker-1"

  # Feature flags
  nvidia_runtime:
    enabled: true
  firewall:
    enabled: true

  # Network configuration
  pod_network_cidr: "10.244.0.0/16"
  service_cidr: "10.96.0.0/12"
  
  # Container runtime
  container_runtime: "containerd"
  containerd_version: "1.6.0"

  # Kubernetes version
  kubernetes_version: "1.28.0"
  
  # CNI configuration
  cni_plugin: "calico"
  calico_version: "v3.26.0"
```

## Features

1. **Node Management**
   - Control plane and worker node configuration
   - SSH access management
   - Node labeling and tainting

2. **Network Configuration**
   - Pod network CIDR configuration
   - Service CIDR configuration
   - CNI plugin selection and setup

3. **Runtime Configuration**
   - Container runtime selection
   - Version management
   - Runtime-specific optimizations

4. **Security Features**
   - SSH key management
   - Firewall configuration
   - RBAC setup

## Node Configuration

### Control Plane Nodes

```yaml
control_plane_nodes:
  - ansible_host: "192.168.1.10"
    ansible_user: "ubuntu"
    node_name: "master-1"
    labels:
      role: "control-plane"
    taints:
      - key: "node-role.kubernetes.io/control-plane"
        effect: "NoSchedule"
```

### Worker Nodes

```yaml
worker_nodes:
  - ansible_host: "192.168.1.11"
    ansible_user: "ubuntu"
    node_name: "worker-1"
    labels:
      role: "worker"
      gpu: "nvidia"
```

## Network Configuration

### Pod Network

```yaml
pod_network:
  cidr: "10.244.0.0/16"
  plugin: "calico"
  calico_version: "v3.26.0"
  mtu: 1440
```

### Service Network

```yaml
service_network:
  cidr: "10.96.0.0/12"
  dns_domain: "cluster.local"
```

## Container Runtime

### Containerd Configuration

```yaml
container_runtime:
  name: "containerd"
  version: "1.6.0"
  config_template: "containerd/config.toml.j2"
  registry_mirrors:
    - "https://registry-1.docker.io"
```

## Security Configuration

### SSH Configuration

```yaml
ssh_config:
  key_path: "/path/to/ssh/key"
  default_user: "ubuntu"
  sudo_without_password: true
```

### Firewall Rules

```yaml
firewall:
  enabled: true
  default_policy: "deny"
  allowed_ports:
    - port: 22
      protocol: tcp
    - port: 6443
      protocol: tcp
```

## Pre-deployment Requirements

Before running `setup_kubernetes.sh`, ensure:

1. **Node Configuration**
   ```yaml
   kubernetes_deployment:
     enabled: true  # Must be set to true
     control_plane_nodes:
       - ansible_host: "YOUR_MASTER_NODE_IP"
         name: "master-1"
         ansible_user: "ubuntu"  # Optional, will use default if not specified
     worker_nodes:
       - ansible_host: "YOUR_WORKER_NODE_IP"
         name: "worker-1"
         ansible_user: "ubuntu"  # Optional, will use default if not specified
   ```

2. **SSH Configuration**
   - SSH key at `~/.ssh/k8s_rsa`
   - Proper permissions on SSH key (600)
   - SSH access to all nodes

3. **System Requirements**
   - Python virtual environment activated
   - Required Python packages installed
   - Proper locale settings (UTF-8)

## Installation Process

1. **Update Configuration**
   ```yaml
   # In user_input.yml
   kubernetes_deployment:
     enabled: true
     # ... node configurations ...
   ```

2. **Run Setup Script**
   ```bash
   chmod +x setup_kubernetes.sh
   ./setup_kubernetes.sh
   ```

3. **Monitor Output**
   The script will:
   - Validate configurations
   - Test node connectivity
   - Generate inventory
   - Deploy Kubernetes components

## Validation and Verification

After the script completes:

1. **Check Node Status**
   ```bash
   kubectl get nodes -o wide
   ```

2. **Verify System Pods**
   ```bash
   kubectl get pods -n kube-system
   ```

3. **Check Cluster Health**
   ```bash
   kubectl cluster-info
   ```

## Troubleshooting

### Common Issues

1. **SSH Connectivity**
   - Verify SSH key permissions
   - Check node IP addresses
   - Ensure proper user configuration

2. **Configuration Issues**
   - Validate user_input.yml format
   - Check node specifications
   - Verify enabled flag is set

3. **Deployment Failures**
   - Check script output for errors
   - Verify node requirements
   - Review connectivity issues

### Error Resolution

1. **SSH Errors**
   ```bash
   # Fix SSH key permissions
   chmod 600 ~/.ssh/k8s_rsa
   
   # Test SSH connection
   ssh -i ~/.ssh/k8s_rsa user@node-ip
   ```

2. **Configuration Errors**
   - Review user_input.yml syntax
   - Ensure all required fields are present
   - Check node accessibility

3. **System Issues**
   - Verify Python environment
   - Check locale settings
   - Ensure sufficient resources

## Post-Installation

After successful installation:
1. Configure additional components
2. Set up monitoring and logging
3. Deploy applications

## Usage

### Pre-deployment Steps

1. Update node IPs in `user_input.yml`:
   ```yaml
   kubernetes_deployment:
     control_plane_nodes:
       - ansible_host: "YOUR_MASTER_NODE_IP"  # Update this IP
         node_name: "master-1"
     worker_nodes:
       - ansible_host: "YOUR_WORKER_NODE_IP"  # Update this IP
         node_name: "worker-1"
   ```

2. Run the Kubernetes setup script:
   ```bash
   ./setup_kubernetes.sh
   ```
   This script will:
   - Initialize the Kubernetes cluster
   - Configure networking
   - Set up required components
   - Apply initial configurations

### Basic Deployment

1. Configure your nodes in `user_input.yml`:
   ```yaml
   kubernetes_deployment:
     control_plane_nodes:
       - ansible_host: "192.168.1.10"
         node_name: "master-1"
     worker_nodes:
       - ansible_host: "192.168.1.11"
         node_name: "worker-1"
   ```


### Advanced Configuration

1. Enable specific features:
   ```yaml
   kubernetes_deployment:
     nvidia_runtime:
       enabled: true
     firewall:
       enabled: true
   ```

2. Configure networking:
   ```yaml
   kubernetes_deployment:
     pod_network_cidr: "10.244.0.0/16"
     service_cidr: "10.96.0.0/12"
     cni_plugin: "calico"
   ```

## Important Notes

1. **IP Configuration**
   - Always update the node IPs in `user_input.yml` before running `setup_kubernetes.sh`
   - Ensure the IPs are reachable and have proper SSH access
   - Verify network connectivity between nodes

2. **Setup Script**
   - `setup_kubernetes.sh` must be run after updating IPs
   - The script requires proper permissions (`chmod +x setup_kubernetes.sh`)
   - Monitor the script output for any errors
   - Wait for the script to complete before proceeding with other configurations

## Validation

### Cluster Health Check

```bash
# Check node status
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Verify networking
kubectl run test-pod --image=busybox -- sleep 3600
kubectl exec test-pod -- ping -c 1 8.8.8.8
```

### Security Validation

```bash
# Check firewall status
sudo ufw status

# Verify SSH access
ssh -i /path/to/key user@node-ip

# Check RBAC
kubectl auth can-i --list
```

## Troubleshooting

1. **Node Join Issues**
   - Verify SSH access
   - Check firewall rules
   - Validate token and certificates

2. **Network Issues**
   - Check CNI plugin status
   - Verify network CIDR configurations
   - Check pod-to-pod communication

3. **Runtime Issues**
   - Verify containerd status
   - Check runtime configuration
   - Validate image pull access 