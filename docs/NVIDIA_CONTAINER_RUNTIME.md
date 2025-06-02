# NVIDIA Container Runtime Configuration

This document describes how to enable and configure NVIDIA Container Runtime in your Kubernetes cluster for the Smart Scaler platform using our Ansible automation.

## Features

- Automatic NVIDIA Container Runtime installation and configuration
- Containerd runtime configuration for GPU workloads
- Kubernetes RuntimeClass setup for NVIDIA workloads
- GPU resource management and allocation
- Node-specific configuration with enhanced options
- Comprehensive validation and testing procedures
- Integration with Smart Scaler AI/ML components

## Prerequisites

- Ubuntu-based nodes with GPU hardware
- NVIDIA GPU(s) installed on target nodes
- NVIDIA drivers installed on the host system (version 470.82.01 or later recommended)
- Kubernetes cluster deployed using our Ansible playbooks
- Proper SSH access to GPU nodes

## Configuration

### Enabling NVIDIA Runtime

To enable comprehensive NVIDIA Container Runtime support, modify your `user_input.yml`:

```yaml
kubernetes_deployment:
  nvidia_runtime:
    enabled: true                            # Enable NVIDIA runtime support
    install_toolkit: true                     # Install NVIDIA Container Toolkit
    configure_containerd: true                # Configure containerd for GPU support
    create_runtime_class: true                # Create Kubernetes RuntimeClass
```

### Enhanced Configuration Options

The enhanced configuration provides granular control over GPU runtime features:

```yaml
nvidia_runtime:
  enabled: true                            # Master switch for NVIDIA runtime
  install_toolkit: true                     # Install NVIDIA Container Toolkit if not present
  configure_containerd: true                # Configure containerd with NVIDIA runtime
  create_runtime_class: true                # Create Kubernetes RuntimeClass for NVIDIA
  
  # Advanced Options (automatically configured)
  toolkit_version: "latest"                 # NVIDIA Container Toolkit version
  runtime_class_name: "nvidia"             # RuntimeClass name for GPU workloads
  default_runtime: false                   # Set NVIDIA as default runtime (not recommended)
  validate_installation: true              # Run validation tests after installation
```

## What's Covered

### 1. NVIDIA Container Toolkit Installation

The automation handles complete toolkit installation:

- **Repository Setup**: Adds NVIDIA Container Toolkit repository with proper GPG keys
- **Package Installation**: Installs `nvidia-container-toolkit` and dependencies
- **Dependency Management**: Ensures all required packages are present
- **Version Compatibility**: Validates compatibility with installed NVIDIA drivers

### 2. Containerd Configuration

Comprehensive containerd runtime configuration:

```toml
# Automatically configured in /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
  runtime_type = "io.containerd.runc.v2"
  runtime_engine = ""
  runtime_root = ""
  privileged_without_host_devices = false
  base_runtime_spec = ""
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
    BinaryName = "/usr/bin/nvidia-container-runtime"
```

### 3. Kubernetes Integration

Complete Kubernetes integration for GPU workloads:

- **RuntimeClass Creation**: Creates `nvidia` RuntimeClass for GPU pods
- **Node Labeling**: Automatically labels GPU nodes
- **Resource Discovery**: Enables GPU resource discovery and allocation
- **Metrics Integration**: Supports GPU metrics collection

### 4. Security and Validation Features

Enhanced security and validation:

- **GPG Key Verification**: Validates repository authenticity
- **Installation Validation**: Runs comprehensive tests after installation
- **Permission Management**: Sets proper file and directory permissions
- **Runtime Testing**: Validates GPU runtime functionality

## Usage

### Deploying with NVIDIA Support

1. **Enable NVIDIA runtime in your configuration**:
   ```yaml
   kubernetes_deployment:
     nvidia_runtime:
       enabled: true
       install_toolkit: true
       configure_containerd: true
       create_runtime_class: true
   ```

2. **Run the Kubernetes setup script**:
   ```bash
   # First deploy Kubernetes cluster
   ./setup_kubernetes.sh
   ```

3. **Deploy Smart Scaler components**:
   ```bash
   # Deploy all components including GPU Operator
   ansible-playbook site.yml
   ```

### Using NVIDIA Runtime in Workloads

After deployment, you can use NVIDIA runtime in various ways:

#### Basic GPU Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  runtimeClassName: nvidia        # Specify NVIDIA runtime
  containers:
    - name: cuda-container
      image: nvidia/cuda:11.8-base
      resources:
        limits:
          nvidia.com/gpu: 1      # Request 1 GPU
      command: ["nvidia-smi"]
```

#### GPU Deployment with Smart Scaler Integration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nim-inference
  namespace: nim
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nim-inference
  template:
    metadata:
      labels:
        app: nim-inference
    spec:
      runtimeClassName: nvidia
      containers:
        - name: nim-service
          image: nvcr.io/nim/meta/llama-3.1-8b-instruct:1.8.4
          resources:
            limits:
              nvidia.com/gpu: 1
            requests:
              memory: "8Gi"
              cpu: "2"
          env:
            - name: LOG_LEVEL
              value: "INFO"
            - name: VLLM_LOG_LEVEL
              value: "INFO"
```

## Validation and Testing

### Installation Validation

The automation includes comprehensive validation procedures:

```bash
# Check NVIDIA runtime installation
nvidia-container-cli info

# Verify containerd configuration
sudo systemctl status containerd

# Check RuntimeClass creation
kubectl get runtimeclass nvidia

# Validate GPU node labeling
kubectl get nodes -l nvidia.com/gpu=true
```

### Functionality Testing

1. **Basic GPU Access Test**:
   ```bash
   kubectl run nvidia-test --image=nvidia/cuda:11.8-base --rm -it \
     --overrides='{"spec":{"runtimeClassName":"nvidia"}}' \
     -- nvidia-smi
   ```

2. **GPU Operator Verification** (if deployed):
   ```bash
   # Check GPU Operator pods
   kubectl get pods -n gpu-operator
   
   # Verify GPU feature discovery
   kubectl get nodes -o json | jq '.items[].status.allocatable'
   ```

3. **NIM Service Testing** (Smart Scaler component):
   ```bash
   # Check NIM service deployment
   kubectl get pods -n nim
   
   # Test inference endpoint
   kubectl port-forward -n nim svc/meta-llama3-8b-instruct 8000:8000
   curl -X POST http://localhost:8000/v1/completions \
     -H "Content-Type: application/json" \
     -d '{"prompt": "Hello", "max_tokens": 50}'
   ```

## Integration with Smart Scaler Components

The NVIDIA runtime integrates seamlessly with Smart Scaler components:

### GPU Operator Integration

```yaml
# Automatically configured when both are enabled
gpu_operator_chart:
  release_values:
    driver:
      enabled: false              # Use host drivers
    toolkit:
      enabled: true               # Use installed toolkit
    dcgm:
      enabled: true               # Enable GPU monitoring
```

### NIM Operator Integration

```yaml
# NIM workloads automatically use NVIDIA runtime
nim_service_manifest:
  variables:
    nim_service_runtime_class: "nvidia"
    nim_service_resources:
      limits:
        nvidia.com/gpu: 1
```

### KEDA GPU Scaling

```yaml
# KEDA can scale based on GPU metrics
keda_scaled_object_manifest:
  variables:
    keda_scaled_object_query: >-
      nvidia_gpu_utilization{job="gpu-metrics"}
```

## Troubleshooting

### Common Issues and Solutions

1. **NVIDIA Runtime Not Found**
   ```bash
   # Check toolkit installation
   which nvidia-container-runtime
   
   # Verify containerd configuration
   sudo cat /etc/containerd/config.toml | grep nvidia
   
   # Restart containerd service
   sudo systemctl restart containerd
   ```

2. **Pod Scheduling Issues**
   ```bash
   # Verify RuntimeClass exists
   kubectl get runtimeclass nvidia -o yaml
   
   # Check node labels for GPU availability
   kubectl get nodes -l nvidia.com/gpu=true
   
   # Validate resource requests/limits
   kubectl describe pod <pod-name>
   ```

3. **GPU Access Problems**
   ```bash
   # Check NVIDIA driver installation
   nvidia-smi
   
   # Verify containerd service status
   sudo systemctl status containerd
   
   # Check pod security context
   kubectl get pod <pod-name> -o yaml | grep -A 10 securityContext
   ```

4. **Permission Issues**
   ```bash
   # Check device permissions
   ls -la /dev/nvidia*
   
   # Verify user groups
   groups
   
   # Check SELinux/AppArmor policies
   sudo dmesg | grep -i denied
   ```

### Advanced Troubleshooting

1. **Container Runtime Debugging**
   ```bash
   # Check containerd logs
   sudo journalctl -u containerd -f
   
   # Test NVIDIA container runtime directly
   sudo nvidia-container-cli info
   
   # Validate runtime configuration
   containerd config dump | grep -A 20 nvidia
   ```

2. **GPU Operator Issues**
   ```bash
   # Check GPU Operator logs
   kubectl logs -n gpu-operator -l app=gpu-operator
   
   # Verify GPU feature discovery
   kubectl get nodes -o json | jq '.items[].metadata.labels' | grep nvidia
   
   # Check device plugin status
   kubectl get daemonset -n gpu-operator
   ```

3. **NIM Service Debugging**
   ```bash
   # Check NIM pod logs
   kubectl logs -n nim -l app=nim-service
   
   # Verify GPU allocation
   kubectl get pod -n nim -o yaml | grep -A 5 resources
   
   # Test model loading
   kubectl exec -n nim <nim-pod> -- nvidia-smi
   ```

## Performance Optimization

### GPU Resource Management

1. **Multi-Instance GPU (MIG) Configuration**:
   ```yaml
   gpu_operator_chart:
     release_values:
       mig:
         strategy: single        # or 'mixed' for heterogeneous workloads
   ```

2. **GPU Sharing and Fractional GPUs**:
   ```yaml
   # Enable GPU time-slicing for multiple workloads
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: time-slicing-config
   data:
     tesla-t4: |
       version: v1
       sharing:
         timeSlicing:
           resources:
           - name: nvidia.com/gpu
             replicas: 4
   ```

### Memory and Compute Optimization

```yaml
# Optimize for specific workloads
nim_service_manifest:
  variables:
    nim_service_env:
      - name: CUDA_VISIBLE_DEVICES
        value: "0"                # Pin to specific GPU
      - name: NVIDIA_VISIBLE_DEVICES
        value: "0"
      - name: CUDA_MPS_PIPE_DIRECTORY
        value: "/tmp/nvidia-mps"  # Enable MPS for better utilization
```

## Monitoring and Metrics

### GPU Metrics Collection

The Smart Scaler platform includes comprehensive GPU monitoring:

```yaml
# Prometheus configuration for GPU metrics
prometheus_stack:
  release_values:
    prometheus:
      prometheusSpec:
        additionalScrapeConfigs:
          - job_name: gpu-metrics
            scrape_interval: 1s
            kubernetes_sd_configs:
              - role: endpoints
                namespaces:
                  names: ["gpu-operator"]
```

### Available GPU Metrics

- GPU utilization percentage
- GPU memory usage
- GPU temperature
- Power consumption
- CUDA kernel execution time
- Memory bandwidth utilization

## Security Considerations

### Container Security

1. **Runtime Security**:
   ```yaml
   # Security context for GPU containers
   securityContext:
     runAsNonRoot: true
     runAsUser: 1000
     capabilities:
       drop: ["ALL"]
     readOnlyRootFilesystem: true
   ```

2. **Resource Limits**:
   ```yaml
   resources:
     limits:
       nvidia.com/gpu: 1
       memory: "8Gi"
       cpu: "2"
     requests:
       memory: "4Gi"
       cpu: "1"
   ```

## Disabling NVIDIA Runtime

To disable NVIDIA runtime support:

1. **Update configuration**:
   ```yaml
   kubernetes_deployment:
     nvidia_runtime:
       enabled: false
   ```

2. **Clean up resources**:
   ```bash
   # Remove RuntimeClass
   kubectl delete runtimeclass nvidia
   
   # Update workloads to use default runtime
   kubectl patch deployment <deployment-name> -p '{"spec":{"template":{"spec":{"runtimeClassName":null}}}}'
   ```

Note: Disabling will not remove existing installations but will skip NVIDIA-related tasks in future deployments.

## Best Practices

### 1. Resource Planning
- Plan GPU allocation based on workload requirements
- Consider GPU memory and compute requirements
- Implement proper resource quotas and limits
- Monitor GPU utilization and plan for scaling

### 2. Workload Optimization
- Use appropriate CUDA versions for your workloads
- Optimize container images for GPU workloads
- Implement proper error handling for GPU operations
- Consider GPU sharing for development workloads

### 3. Monitoring and Alerting
- Set up alerts for GPU utilization thresholds
- Monitor GPU temperature and power consumption
- Track CUDA out-of-memory errors
- Implement proper logging for GPU workloads

### 4. Security
- Use minimal container images for GPU workloads
- Implement proper RBAC for GPU resources
- Regular security updates for NVIDIA drivers and toolkit
- Monitor for unauthorized GPU usage

## Related Documentation

- [User Input Configuration Guide](USER_INPUT_CONFIGURATION.md) - Complete configuration guide
- [User Input Reference](USER_INPUT_REFERENCE.md) - Detailed configuration reference
- [Kubernetes Configuration](KUBERNETES_CONFIGURATION.md) - Kubernetes cluster setup
- [Kubernetes Firewall](KUBERNETES_FIREWALL.md) - Network security configuration 