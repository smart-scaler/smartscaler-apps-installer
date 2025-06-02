# Kubernetes Configuration

This document describes the Kubernetes cluster configuration options and deployment settings for the Smart Scaler platform deployment using our Ansible automation.

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
   - Configures worker nodes (if specified)
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
  enabled: false                               # Enable/disable Kubernetes cluster deployment
  
  # Firewall Configuration
  firewall:
    enabled: true                             # Enable/disable firewall configuration
    allow_additional_ports: []                # Additional ports to allow
    
  # NVIDIA Runtime Configuration
  nvidia_runtime:
    enabled: true                            # Enable/disable NVIDIA runtime configuration
    install_toolkit: true                     # Install NVIDIA Container Toolkit if not present
    configure_containerd: true                # Configure containerd with NVIDIA runtime
    create_runtime_class: true                # Create Kubernetes RuntimeClass for NVIDIA
  
  # SSH Configuration
  ssh_key_path: "/root/.ssh/k8s_rsa"         # Absolute Path to SSH private key for node access
  default_ansible_user: "root"               # Default SSH user for node access
  
  # Node Configuration
  control_plane_nodes:
    - name: master-k8s                        # Hostname/identifier for the node
      ansible_host: "127.0.0.1"             # IP address or DNS name of the node
      ansible_user: root                      # SSH user for this specific node
  
  # Kubernetes Components Configuration
  network_plugin: calico                      # CNI plugin for pod networking
  container_runtime: containerd               # Container runtime
  dns_mode: coredns                          # DNS service for the cluster
```

## Enhanced Features

### 1. Firewall Management

The deployment now includes comprehensive firewall configuration:

```yaml
firewall:
  enabled: true                             # Enable automatic firewall management
  allow_additional_ports:                   # Additional ports to open
    - "8080"                               # Custom HTTP port
    - "9090"                               # Prometheus metrics
    - "3000"                               # Grafana dashboard
```

**Automatically Configured Ports:**
- **Control Plane Ports**: 6443 (API server), 2379-2380 (etcd), 10250 (kubelet), 10259 (scheduler), 10257 (controller-manager)
- **Worker Node Ports**: 10250 (kubelet), 30000-32767 (NodePort services)
- **CNI Ports**: 179 (Calico BGP), 4789 (Calico VXLAN), 5473 (Calico Typha)
- **Additional Services**: 9099 (health checks), custom application ports

### 2. NVIDIA Runtime Integration

Enhanced GPU support with comprehensive NVIDIA runtime configuration:

```yaml
nvidia_runtime:
  enabled: true                            # Enable NVIDIA runtime support
  install_toolkit: true                     # Install NVIDIA Container Toolkit
  configure_containerd: true                # Configure containerd for GPU support
  create_runtime_class: true                # Create Kubernetes RuntimeClass
```

**Features Included:**
- NVIDIA Container Toolkit installation and configuration
- Containerd runtime configuration for GPU workloads
- Kubernetes RuntimeClass creation for NVIDIA workloads
- GPU resource management and allocation
- Validation and testing of GPU functionality

### 3. Network Configuration

```yaml
# Network Configuration
network_plugin: calico                      # CNI plugin selection
container_runtime: containerd               # Container runtime
dns_mode: coredns                          # DNS service configuration

# Advanced Network Settings (configured automatically)
pod_network_cidr: "10.233.64.0/18"        # Pod network CIDR
service_cidr: "10.233.0.0/18"             # Service network CIDR
```

### 4. Security Configuration

Enhanced security features:

```yaml
# SSH Configuration
ssh_key_path: "/root/.ssh/k8s_rsa"         # Must be absolute path
default_ansible_user: "root"               # Default SSH user

# Security Features (automatically configured)
- RBAC enabled by default
- Network policies support
- Pod security standards
- Audit logging
```

## Node Configuration

### Control Plane Nodes

```yaml
control_plane_nodes:
  - name: master-k8s                        # Node identifier
    ansible_host: "127.0.0.1"             # Node IP address
    ansible_user: root                      # SSH user for this node
```

**Control Plane Features:**
- Kubernetes API server
- etcd cluster member
- Controller manager
- Scheduler
- CNI plugin installation

### Worker Nodes (Optional)

```yaml
worker_nodes:
  - name: worker-1
    ansible_host: "192.168.1.11"
    ansible_user: root
```

**Worker Node Features:**
- Kubelet service
- Container runtime
- CNI plugin
- GPU support (if enabled)

## Deployment Process

### Step 1: Pre-deployment Configuration

1. **Update Node Configuration**
   ```yaml
   kubernetes_deployment:
     enabled: true                          # Enable Kubernetes deployment
     ssh_key_path: "/root/.ssh/k8s_rsa"    # Update with your SSH key path
     control_plane_nodes:
       - name: master-k8s
         ansible_host: "YOUR_NODE_IP"       # Update with actual IP
         ansible_user: root
   ```

2. **Configure Features**
   ```yaml
   firewall:
     enabled: true                          # Enable firewall management
   nvidia_runtime:
     enabled: true                          # Enable for GPU workloads
   ```

### Step 2: Run Deployment Script

```bash
# Make script executable
chmod +x setup_kubernetes.sh

# Run the deployment
./setup_kubernetes.sh
```

### Step 3: Verification

```bash
# Check cluster status
kubectl get nodes

# Verify pods are running
kubectl get pods -A

# Check GPU nodes (if NVIDIA runtime enabled)
kubectl get nodes -l nvidia.com/gpu=true

# Verify firewall rules
sudo ufw status verbose
```

## Advanced Configuration Options

### Custom Network Configuration

```yaml
# Advanced networking (automatically configured)
kube_network_plugin: calico
kube_pods_subnet: 10.233.64.0/18
kube_service_addresses: 10.233.0.0/18
cluster_name: cluster.local
```

### GPU Workload Configuration

For GPU-enabled clusters:

```yaml
# GPU Runtime Configuration
nvidia_runtime:
  enabled: true
  install_toolkit: true
  configure_containerd: true
  create_runtime_class: true

# Automatically creates RuntimeClass for GPU workloads
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: nvidia
handler: nvidia
```

### Security Hardening

```yaml
# Security features (automatically enabled)
- RBAC authorization
- Network policies
- Pod security standards
- Audit logging
- TLS encryption for all communications
```

## Troubleshooting

### Common Issues and Solutions

1. **SSH Connection Issues**
   ```bash
   # Verify SSH connectivity
   ssh -i /root/.ssh/k8s_rsa root@NODE_IP
   
   # Check SSH key permissions
   chmod 600 /root/.ssh/k8s_rsa
   ```

2. **Node Not Ready**
   ```bash
   # Check kubelet status
   systemctl status kubelet
   
   # Check kubelet logs
   journalctl -u kubelet -f
   ```

3. **DNS Resolution Issues**
   ```bash
   # Check CoreDNS pods
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   
   # Test DNS resolution
   kubectl run test-dns --image=busybox --rm -it -- nslookup kubernetes
   ```

4. **Network Connectivity**
   ```bash
   # Check Calico pods
   kubectl get pods -n kube-system -l k8s-app=calico-node
   
   # Verify network policy support
   kubectl get networkpolicies -A
   ```

5. **GPU Issues (if enabled)**
   ```bash
   # Check NVIDIA runtime
   kubectl get runtimeclass nvidia
   
   # Test GPU access
   kubectl run gpu-test --image=nvidia/cuda:11.0-base --rm -it -- nvidia-smi
   ```

### Firewall Troubleshooting

1. **Check Firewall Status**
   ```bash
   sudo ufw status verbose
   ```

2. **Verify Required Ports**
   ```bash
   # Test API server connectivity
   nc -zv NODE_IP 6443
   
   # Test kubelet port
   nc -zv NODE_IP 10250
   ```

3. **Add Custom Ports**
   ```yaml
   firewall:
     enabled: true
     allow_additional_ports:
       - "8080"    # Custom application port
       - "9090"    # Prometheus
   ```

### GPU Runtime Troubleshooting

1. **Verify NVIDIA Toolkit Installation**
   ```bash
   nvidia-container-cli info
   ```

2. **Check Containerd Configuration**
   ```bash
   cat /etc/containerd/config.toml | grep nvidia
   ```

3. **Test GPU Pod**
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: gpu-test
   spec:
     runtimeClassName: nvidia
     containers:
     - name: cuda
       image: nvidia/cuda:11.0-base
       command: ["nvidia-smi"]
       resources:
         limits:
           nvidia.com/gpu: 1
   ```

## Post-Deployment Steps

After successful Kubernetes deployment:

1. **Install Core Components**
   ```bash
   # Run the main playbook for Smart Scaler components
   ansible-playbook site.yml
   ```

2. **Verify Component Installation**
   ```bash
   # Check GPU Operator (if enabled)
   kubectl get pods -n gpu-operator
   
   # Check Prometheus Stack
   kubectl get pods -n monitoring
   
   # Check KEDA
   kubectl get pods -n keda
   ```

3. **Configure Monitoring**
   ```bash
   # Access Grafana dashboard
   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
   ```

4. **Test Smart Scaler Components**
   ```bash
   # Check NIM services
   kubectl get pods -n nim
   
   # Check Smart Scaler inference
   kubectl get pods -n smart-scaler
   ```

## Best Practices

### 1. Pre-deployment
- Always verify SSH connectivity to all nodes
- Ensure proper SSH key permissions (600)
- Update node IP addresses in configuration
- Plan for adequate storage and compute resources

### 2. Security
- Enable firewall management for production deployments
- Use strong SSH keys and proper key management
- Implement network policies for workload isolation
- Regular security updates and patching

### 3. GPU Workloads
- Verify NVIDIA drivers are installed on target nodes
- Enable NVIDIA runtime only on GPU-enabled nodes
- Plan for GPU resource allocation and sharing
- Monitor GPU utilization and performance

### 4. Network Configuration
- Choose appropriate CNI plugin for your environment
- Plan for pod and service network CIDRs
- Consider multi-zone deployments for high availability
- Implement proper ingress and load balancing

### 5. Monitoring and Maintenance
- Set up monitoring and alerting from day one
- Plan for backup and disaster recovery
- Implement proper logging and audit trails
- Regular cluster health checks and maintenance

## Related Documentation

- [User Input Configuration Guide](USER_INPUT_CONFIGURATION.md) - Complete configuration guide
- [User Input Reference](USER_INPUT_REFERENCE.md) - Detailed configuration reference
- [NVIDIA Container Runtime](NVIDIA_CONTAINER_RUNTIME.md) - GPU runtime configuration
- [Kubernetes Firewall](KUBERNETES_FIREWALL.md) - Network security configuration 