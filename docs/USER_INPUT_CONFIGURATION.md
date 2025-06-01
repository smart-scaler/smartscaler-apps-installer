# User Input Configuration Guide

This document provides a comprehensive guide to configuring the `user_input.yml` file, which controls all aspects of the deployment.

## Configuration Structure

The `user_input.yml` file is organized into several main sections:

```yaml
# Global Settings
global_kubeconfig: "files/kubeconfig"
global_kubecontext: "your-cluster-context"

# Kubernetes Deployment Configuration
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

# Component Installation Order
execution_order:
  - gpu_operator_chart
  - prometheus_stack
  - pushgateway_manifest
  - keda_chart
  - nim_operator_chart
  - create_ngc_secrets
  - verify_ngc_secrets

# Helm Chart Configurations
helm_charts:
  gpu_operator_chart:
    name: "gpu-operator"
    chart: "gpu-operator"
    version: "v25.3.0"
    namespace: "gpu-operator"
    create_namespace: true
    values:
      driver:
        enabled: false
      toolkit:
        enabled: true

  prometheus_stack:
    name: "prometheus"
    chart: "kube-prometheus-stack"
    version: "55.5.0"
    namespace: "monitoring"
    create_namespace: true
    values:
      grafana:
        enabled: true
        adminPassword: "admin"

  keda_chart:
    name: "keda"
    chart: "keda"
    namespace: "keda"
    create_namespace: true
    values:
      metrics:
        enabled: true

  nim_operator_chart:
    name: "nim"
    chart: "k8s-nim-operator"
    namespace: "nim"
    create_namespace: true
    values:
      operator:
        logLevel: "info"

# Manifest Configurations
manifests:
  pushgateway_manifest:
    name: "pushgateway"
    manifest_file: "files/pushgateway.yaml"
    namespace: "monitoring"
    variables:
      image: "prom/pushgateway:v1.4.3"
      replicas: 1

# NIM Cache Configuration
nim_cache_manifest:
  name: "nim-cache-setup"
  manifest_file: "files/nim-cache.yaml.j2"
  namespace: "nim"
  variables:
    nim_cache_name: "meta-llama3-8b-instruct"
    nim_cache_namespace: "nim"
    nim_cache_runtime_class: "nvidia"
    nim_cache_model_puller: "nvcr.io/nim/meta/llama-3.1-8b-instruct:1.8.4"
    nim_cache_model_engine: "vllm"
    nim_cache_tensor_parallelism: "1"
    nim_cache_qos_profile: "throughput"
    nim_cache_pvc_size: "200Gi"

# Command Execution Configurations
command_exec:
  - name: "create_ngc_secrets"
    command: |
      kubectl create secret docker-registry ngc-secret \
        --docker-server=nvcr.io \
        --docker-username=\$oauthtoken \
        --docker-password={{ ngc_api_key }} \
        -n nim
    env:
      NGC_API_KEY: "{{ ngc_api_key }}"
```

## Configuration Sections

### 1. Global Settings
- `global_kubeconfig`: Path to the Kubernetes configuration file
- `global_kubecontext`: Kubernetes context to use

### 2. Kubernetes Deployment
Detailed in [Kubernetes Configuration](KUBERNETES_CONFIGURATION.md)

### 3. Component Installation
- `execution_order`: Defines the sequence of component installation
- Supports:
  - Helm charts
  - Kubernetes manifests
  - Shell commands

### 4. Helm Charts
Each chart configuration includes:
- `name`: Release name
- `chart`: Chart name
- `version`: Chart version
- `namespace`: Target namespace
- `values`: Chart-specific values

### 5. Manifests
Each manifest configuration includes:
- `name`: Resource name
- `manifest_file`: Path to manifest file
- `namespace`: Target namespace
- `variables`: Template variables

### 6. NIM Cache
Configuration for NVIDIA Instance Manager cache:
- Basic settings (name, namespace)
- Runtime configuration
- Model settings
- Storage configuration

### 7. Command Execution
For shell commands that need to be executed:
- `name`: Command identifier
- `command`: Shell command to execute
- `env`: Environment variables

## Usage Examples

### 1. Enabling NVIDIA Runtime

```yaml
kubernetes_deployment:
  nvidia_runtime:
    enabled: true
```

### 2. Configuring Prometheus Stack

```yaml
helm_charts:
  prometheus_stack:
    name: "prometheus"
    chart: "kube-prometheus-stack"
    version: "55.5.0"
    namespace: "monitoring"
    values:
      grafana:
        enabled: true
        adminPassword: "admin"
```

### 3. Setting Up NIM Cache

```yaml
nim_cache_manifest:
  name: "nim-cache-setup"
  variables:
    nim_cache_name: "your-model-name"
    nim_cache_model_puller: "your-model-image"
    nim_cache_pvc_size: "200Gi"
```

## Best Practices

1. **Initial Setup**
   - Update node IPs before running `setup_kubernetes.sh`
   - Run `setup_kubernetes.sh` before any other configuration
   - Verify cluster initialization before proceeding

2. **Version Control**
   - Always specify exact versions for charts
   - Use semantic versioning
   - Document version changes

3. **Security**
   - Never commit sensitive values
   - Use environment variables for secrets
   - Implement proper RBAC

4. **Resource Management**
   - Set appropriate resource limits
   - Configure proper storage sizes
   - Monitor resource usage

5. **Maintenance**
   - Regular updates of components
   - Backup configurations
   - Document customizations

## Important Prerequisites

### Node IP Configuration and Kubernetes Setup

1. Update node IPs in configuration:
   ```yaml
   kubernetes_deployment:
     control_plane_nodes:
       - ansible_host: "YOUR_MASTER_NODE_IP"  # Update this
         node_name: "master-1"
     worker_nodes:
       - ansible_host: "YOUR_WORKER_NODE_IP"  # Update this
         node_name: "worker-1"
   ```

2. Run the Kubernetes setup script:
   ```bash
   chmod +x setup_kubernetes.sh
   ./setup_kubernetes.sh
   ```

3. Verify the setup:
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

### Post-Setup Configuration

After successful Kubernetes setup:
1. Proceed with component installations
2. Configure additional features (NVIDIA runtime, firewall, etc.)
3. Deploy applications and services 