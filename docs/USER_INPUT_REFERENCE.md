# User Input Configuration Reference

This document provides a detailed reference for all configuration options in the `user_input.yml` file.

## Table of Contents

1. [Kubernetes Deployment](#kubernetes-deployment)
2. [Global Settings](#global-settings)
3. [Helm Charts](#helm-charts)
4. [Manifests](#manifests)
5. [Command Execution](#command-execution)

## Kubernetes Deployment

```yaml
kubernetes_deployment:
  enabled: true                                # Enable/disable Kubernetes deployment
  ssh_key_path: "/home/user/.ssh/k8s_rsa"     # MUST be absolute path to SSH private key
  default_ansible_user: "root"                 # Default SSH user for node access
  
  # Control plane node configuration
  control_plane_nodes:
    - name: master-k8s                        # Node name for the control plane
      ansible_host: 172.16.0.10               # Node IP address
      ansible_user: root                      # SSH user (overrides default_ansible_user)
  
  # Optional worker nodes configuration
  worker_nodes:
    - name: worker-1                          # Worker node name
      ansible_host: 172.16.0.11               # Worker node IP address
      ansible_user: root                      # SSH user (overrides default_ansible_user)
  
  # Kubernetes component configuration
  network_plugin: calico                      # Network plugin (calico, flannel, weave, cilium)
  container_runtime: containerd               # Container runtime (containerd, crio)
  dns_mode: coredns                          # DNS mode (coredns, nodelocaldns)
```

### SSH Key Requirements

- The `ssh_key_path` MUST be an absolute path
- Example valid path: `/home/user/.ssh/k8s_rsa`
- Example invalid path: `~/.ssh/k8s_rsa`
- Key permissions must be set to 600: `chmod 600 /path/to/key`

### Node Configuration

Each node in `control_plane_nodes` and `worker_nodes` supports:
- `name`: Unique identifier for the node
- `ansible_host`: IP address or hostname
- `ansible_user`: SSH user (optional, falls back to default_ansible_user)
- `ansible_port`: SSH port (optional, defaults to 22)

## Global Settings

```yaml
# Docker registry credentials
global_image_pull_secret:
  repository: "https://index.docker.io/v1/"   # Registry URL
  username: ""                                # Registry username
  password: ""                                # Registry password

# Kubernetes configuration
global_kubeconfig: "files/kubeconfig"         # Path to kubeconfig file
global_kubecontext: "default"                 # Kubernetes context to use
use_global_context: true                      # Use global context for all operations

# Helm configuration
use_local_charts: false                       # Use local chart files instead of remote repos
local_charts_path: "charts"                   # Path to local charts if use_local_charts is true
global_chart_repo_url: ""                     # Default Helm repository URL
global_repo_username: ""                      # Helm repository username
global_repo_password: ""                      # Helm repository password
readd_helm_repos: true                        # Re-add Helm repos even if they exist
```

## Helm Charts

### GPU Operator

```yaml
gpu_operator_chart:
  release_name: gpu-operator           # Helm release name
  chart_ref: gpu-operator             # Chart reference
  release_namespace: gpu-operator     # Target namespace
  create_namespace: true             # Create namespace if it doesn't exist
  wait: true                         # Wait for deployment completion
  chart_version: v25.3.0            # Chart version to install
  release_values:                    # Chart-specific values
    mig:
      strategy: none                 # MIG strategy
    dcgm:
      enabled: true                  # Enable DCGM
    driver:
      enabled: false                # Disable driver installation
```

### Prometheus Stack

```yaml
prometheus_stack:
  release_name: prometheus
  chart_ref: kube-prometheus-stack
  release_namespace: monitoring
  chart_version: "55.5.0"
  release_values:
    prometheus:
      prometheusSpec:
        retention: 15d              # Data retention period
        additionalScrapeConfigs:    # Additional scrape configurations
          - job_name: gpu-metrics   # GPU metrics collection
            scrape_interval: 1s
            # ... additional scrape config ...
```

## Manifests

### NIM Cache

```yaml
nim_cache_manifest:
  name: nim-cache-setup             # Manifest name
  manifest_file: "files/nim-cache.yaml.j2"  # Template file
  namespace: nim                    # Target namespace
  variables:                        # Template variables
    nim_cache_name: "model-name"    # Cache resource name
    nim_cache_namespace: "nim"      # Namespace
    nim_cache_runtime_class: "nvidia"  # Runtime class
    # ... additional variables ...
```

### NIM Service

```yaml
nim_service_manifest:
  name: nim-service-setup
  manifest_file: "files/nim-service.yaml.j2"
  namespace: nim
  variables:
    nim_service_name: "service-name"
    nim_service_replicas: 1
    nim_service_resources:
      limits:
        nvidia.com/gpu: 1
    # ... additional variables ...
```

## Command Execution

```yaml
command_exec:
  - name: "create_ngc_secrets"      # Command name
    kubeconfig: "{{ global_kubeconfig }}"  # Kubeconfig to use
    commands:                       # List of commands to execute
      - cmd: "kubectl create secret..."  # Command to run
        env:                       # Environment variables
          NGC_API_KEY: "{{ ngc_api_key }}"
        ignore_errors: false      # Error handling
```

## Environment Variables

The following environment variables are used:

```yaml
# NGC credentials
ngc_api_key: "{{ lookup('env', 'NGC_API_KEY') }}"
ngc_docker_api_key: "{{ lookup('env', 'NGC_DOCKER_API_KEY') }}"

# Avesha credentials
avesha_docker_username: "{{ lookup('env', 'AVESHA_DOCKER_USERNAME') }}"
avesha_docker_password: "{{ lookup('env', 'AVESHA_DOCKER_PASSWORD') }}"
```

## Execution Order

```yaml
execution_order:
  - gpu_operator_chart                        # NVIDIA GPU operator
  - prometheus_stack                          # Monitoring stack
  - pushgateway_manifest                      # Metrics pushgateway
  - keda_chart                               # KEDA autoscaler
  - nim_operator_chart                       # NVIDIA Inference Microservice
  # ... additional components ...
```

## Helm Charts Configuration

Each Helm chart in the `helm_charts` section supports:
- `release_name`: Name of the Helm release
- `chart_ref`: Chart name/reference
- `release_namespace`: Kubernetes namespace
- `create_namespace`: Whether to create the namespace
- `wait`: Wait for deployment completion
- `chart_version`: Specific chart version
- `chart_repo_url`: Chart repository URL
- `release_values`: Chart-specific values

Example:
```yaml
helm_charts:
  gpu_operator_chart:
    release_name: gpu-operator
    chart_ref: gpu-operator
    release_namespace: gpu-operator
    create_namespace: true
    wait: true
    chart_version: v25.3.0
    release_values:
      mig:
        strategy: none
      dcgm:
        enabled: true
      driver:
        enabled: false
    chart_repo_url: "https://helm.ngc.nvidia.com/nvidia"
```

## Manifest Configuration

Each manifest in the `manifests` section supports:
- `name`: Unique identifier
- `manifest_file`: Path to manifest file
- `namespace`: Target namespace
- `wait`: Wait for deployment completion
- `wait_timeout`: Maximum wait time
- `validate`: Enable manifest validation
- `variables`: Template variables

Example:
```yaml
manifests:
  pushgateway_manifest:
    name: pushgateway-setup
    manifest_file: "files/pushgateway.yaml"
    namespace: pushgateway-system
    wait: true
    wait_timeout: 300
    validate: true
    variables:
      namespace: monitoring
``` 