# NVIDIA Container Runtime Configuration

This document describes how to enable and configure NVIDIA Container Runtime in your Kubernetes cluster using our Ansible automation.

## Features

- Automatic NVIDIA Container Runtime installation
- Containerd runtime configuration
- Kubernetes RuntimeClass setup
- Node-specific configuration
- Status reporting and validation

## Prerequisites

- Ubuntu-based nodes
- NVIDIA GPU(s) installed on target nodes
- NVIDIA drivers installed on the host system
- Kubernetes cluster deployed using our Ansible playbooks

## Configuration

### Enabling NVIDIA Runtime

To enable NVIDIA Container Runtime support, modify your `user_input.yml`:

```yaml
kubernetes_deployment:
  nvidia_runtime:
    enabled: true  # Set to false to disable
```

### What's Covered

1. **NVIDIA Container Toolkit Installation**
   - Repository setup with GPG keys
   - Required dependencies installation
   - Toolkit installation and validation

2. **Containerd Configuration**
   - Automatic configuration file management
   - NVIDIA runtime integration
   - Service restart handling

3. **Kubernetes Integration**
   - RuntimeClass creation
   - Node configuration
   - Validation checks

4. **Security Features**
   - GPG key verification
   - Secure repository configuration
   - Proper permissions management

## Usage

### Deploying with NVIDIA Support

1. Enable NVIDIA runtime in your configuration:
   ```yaml
   kubernetes_deployment:
     nvidia_runtime:
       enabled: true
   ```

2. Run the Ansible playbook:
   ```bash
   ansible-playbook -i inventory/your-inventory main.yml
   ```

### Using NVIDIA Runtime in Pods

After deployment, you can use NVIDIA runtime in your pods by specifying the RuntimeClass:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  runtimeClassName: nvidia  # Specify NVIDIA runtime
  containers:
    - name: cuda-container
      image: nvidia/cuda:11.0-base
      resources:
        limits:
          nvidia.com/gpu: 1  # Request 1 GPU
```

### Validation

To verify the setup:

1. Check RuntimeClass:
   ```bash
   kubectl get runtimeclass nvidia
   ```

2. Verify NVIDIA runtime on nodes:
   ```bash
   kubectl get nodes -o wide
   ```

3. Test GPU access:
   ```bash
   kubectl run nvidia-test --image=nvidia/cuda:11.0-base --rm -it -- nvidia-smi
   ```

## Troubleshooting

Common issues and solutions:

1. **NVIDIA Runtime Not Found**
   - Verify containerd configuration
   - Check NVIDIA Container Toolkit installation
   - Ensure GPU drivers are installed

2. **Pod Scheduling Issues**
   - Verify RuntimeClass exists
   - Check node labels for GPU availability
   - Validate resource requests/limits

3. **GPU Access Problems**
   - Check NVIDIA driver installation
   - Verify containerd service status
   - Review pod security context

## Disabling NVIDIA Runtime

To disable NVIDIA runtime support:

1. Set `enabled: false` in your configuration:
   ```yaml
   kubernetes_deployment:
     nvidia_runtime:
       enabled: false
   ```

2. Run the playbook again to apply changes

Note: This won't remove existing configurations but will skip NVIDIA-related tasks in future runs. 