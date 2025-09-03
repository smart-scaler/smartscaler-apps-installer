# NVIDIA Prerequisites Role

This Ansible role automatically detects NVIDIA GPUs and installs the necessary container runtime support for GPU-accelerated workloads in Kubernetes clusters.

**🚀 Platform Support**: This role works for **BOTH** K3s and Kubespray Kubernetes deployments!

## Features

- **Automatic GPU Detection**: Uses multiple methods to detect NVIDIA GPUs
- **Container Runtime Setup**: Installs and configures NVIDIA Container Toolkit
- **Containerd Integration**: Configures containerd for NVIDIA runtime support
- **Kubernetes Integration**: Creates RuntimeClass for GPU workloads
- **Cross-Platform Support**: Works on Ubuntu, Debian, RHEL/CentOS
- **Verification**: Tests GPU access and container runtime functionality

## Requirements

- Ansible 2.9+
- Target nodes with NVIDIA GPUs (optional - role will skip if no GPUs detected)
- Root/sudo access on target nodes
- Internet access for package installation

## Role Variables

### Main Configuration

```yaml
nvidia_prerequisites:
  enabled: true                    # Enable/disable the role
  
  # Container Runtime Configuration
  container_runtime:
    install_toolkit: true          # Install NVIDIA Container Toolkit
    configure_containerd: true     # Configure containerd for NVIDIA
    create_runtime_class: true     # Create Kubernetes RuntimeClass
    architecture: "amd64"          # Package architecture
  
  # Driver Configuration
  driver:
    auto_install: false            # Auto-install drivers (use with caution)
    version: "latest"              # Driver version
    install_method: "package"      # Installation method
  
  # Detection Methods
  detection:
    enabled: true
    methods:
      - nvidia_smi                 # Use nvidia-smi command
      - lspci                      # Use lspci to find devices
      - device_files               # Check /dev/nvidia* files
      - kernel_modules             # Check loaded modules
  
  # Verification
  verification:
    test_gpu_access: true          # Test GPU access from containers
    create_test_pod: true          # Create test pod
    timeout: 300                   # Test timeout
```

## Dependencies

None - this is a standalone role.

## Example Playbook

### Basic Usage

```yaml
---
- name: Setup NVIDIA Prerequisites
  hosts: all
  become: true
  gather_facts: true
  
  roles:
    - nvidia_prerequisites
```

### With Custom Configuration

```yaml
---
- name: Setup NVIDIA Prerequisites with Custom Config
  hosts: all
  become: true
  gather_facts: true
  
  vars:
    nvidia_prerequisites:
      enabled: true
      container_runtime:
        install_toolkit: true
        configure_containerd: true
        create_runtime_class: true
        architecture: "amd64"
      detection:
        methods:
          - nvidia_smi
          - lspci
      verification:
        test_gpu_access: true
        timeout: 600
  
  roles:
    - nvidia_prerequisites
```

## What This Role Does

### 1. GPU Detection
- Checks for NVIDIA GPUs using multiple detection methods
- Verifies GPU presence before proceeding with installation
- Skips installation if no GPUs are detected

### 2. Container Runtime Installation
- Installs NVIDIA Container Toolkit
- Installs NVIDIA Container Runtime
- Adds NVIDIA repositories for package management

### 3. Containerd Configuration
- Backs up existing containerd configuration
- Adds NVIDIA runtime configuration
- Restarts containerd service

### 4. Kubernetes Integration
- Creates RuntimeClass manifest for GPU workloads
- Applies RuntimeClass when cluster is ready
- Enables GPU scheduling with node selectors

### 5. Verification
- Tests NVIDIA Container CLI
- Verifies runtime version
- Creates test container to verify GPU access
- Provides comprehensive installation summary

## Detection Methods

The role uses multiple methods to detect NVIDIA GPUs:

1. **nvidia-smi**: Checks if NVIDIA drivers are installed and GPUs are accessible
2. **lspci**: Scans PCI bus for NVIDIA devices
3. **Device Files**: Looks for `/dev/nvidia*` device files
4. **Kernel Modules**: Checks for loaded NVIDIA kernel modules

## Supported Operating Systems

- **Ubuntu**: 18.04 (Bionic), 20.04 (Focal), 22.04 (Jammy)
- **Debian**: 10 (Buster), 11 (Bullseye)
- **RHEL/CentOS**: 7, 8, 9

## GPU Workload Support

After running this role, your cluster will support:

- **GPU Pods**: Pods can request `nvidia.com/gpu` resources
- **Runtime Class**: Use `runtimeClassName: nvidia` for GPU workloads
- **Container Access**: Containers can access GPU resources
- **Multi-GPU**: Support for multiple GPUs per node

## Example GPU Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  runtimeClassName: nvidia
  containers:
  - name: gpu-test
    image: nvidia/cuda:11.0-base-ubuntu18.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
```

## Troubleshooting

### Common Issues

1. **No GPUs Detected**
   - Verify NVIDIA drivers are installed
   - Check if GPUs are physically present
   - Review detection method configuration

2. **Container Runtime Installation Failed**
   - Check internet connectivity
   - Verify package repository access
   - Review architecture settings

3. **Containerd Configuration Issues**
   - Check containerd service status
   - Verify configuration file syntax
   - Review backup and restore process

### Debug Mode

Enable verbose output:

```yaml
nvidia_prerequisites:
  advanced:
    verbose: true
```

## Integration with Other Roles

This role is designed to work alongside:

- **Jetson Prerequisites**: For Jetson device support
- **K3s Server/Agent**: For K3s cluster deployment
- **Kubespray**: For standard Kubernetes deployment
- **GPU Operator**: For advanced GPU management

## License

Apache 2.0

## Author Information

K3s Automation Team

---

**🎯 Key Takeaway**: This role provides **platform-agnostic** NVIDIA GPU support for any Kubernetes distribution!
