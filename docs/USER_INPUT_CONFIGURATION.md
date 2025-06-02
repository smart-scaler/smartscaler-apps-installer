# User Input Configuration Guide

This document provides a comprehensive guide to configuring the `user_input.yml` file, which controls all aspects of the Smart Scaler platform deployment.

## Configuration Structure

The `user_input.yml` file is organized into several main sections:

```yaml
# Kubernetes Deployment Configuration
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

# Global Configuration
global_image_pull_secret:
  repository: "https://index.docker.io/v1/"
  username: ""
  password: ""

global_kubeconfig: "files/kubeconfig"
global_kubecontext: "kubecontext" 
use_global_context: true

# Helm repository settings
use_local_charts: false
local_charts_path: "charts"
global_chart_repo_url: ""
global_repo_username: ""
global_repo_password: ""
readd_helm_repos: true

# Environment Variables
ngc_api_key: "{{ lookup('env', 'NGC_API_KEY') }}"
ngc_docker_api_key: "{{ lookup('env', 'NGC_DOCKER_API_KEY') }}"
avesha_docker_username: "{{ lookup('env', 'AVESHA_DOCKER_USERNAME') }}"
avesha_docker_password: "{{ lookup('env', 'AVESHA_DOCKER_PASSWORD') }}"

# Validation and Execution Configuration
validate_prerequisites:
  enabled: true            
execution_order_enabled: true

# Complete Execution Order (15 steps)
execution_order:
  - gpu_operator_chart                 # Install GPU Operator
  - prometheus_stack                   # Deploy monitoring stack
  - pushgateway_manifest              # Deploy Pushgateway for custom metrics
  - keda_chart                        # Install KEDA for autoscaling
  - nim_operator_chart                # Deploy NIM Operator
  - create_ngc_secrets                # Create NGC secrets for NVIDIA registry
  - verify_ngc_secrets                # Verify NGC secret creation
  - create_avesha_secret              # Create Avesha Docker registry secrets
  - nim_cache_manifest                # Deploy NIM Cache for model preparation
  - nim_service_manifest              # Deploy NIM Service for inference
  - keda_scaled_object_manifest       # Configure KEDA scaling
  - create_inference_pod_configmap    # Create Smart Scaler configuration
  - smart_scaler_inference            # Deploy Smart Scaler inference component
  - create_locust_configmap           # Create Locust test configuration
  - locust_manifest                   # Deploy load testing framework
```

## Configuration Sections

### 1. Kubernetes Deployment Configuration

The Kubernetes deployment section now includes enhanced features:

#### Basic Configuration
```yaml
kubernetes_deployment:
  enabled: false                               # Set to true to enable K8s installation
  ssh_key_path: "/root/.ssh/k8s_rsa"         # MUST be absolute path
  default_ansible_user: "root"               # Default SSH user
```

#### Firewall Configuration
```yaml
firewall:
  enabled: true                             # Enable firewall management
  allow_additional_ports: ["8080", "9090"] # Additional ports to open
```

#### NVIDIA Runtime Configuration
```yaml
nvidia_runtime:
  enabled: true                            # Enable NVIDIA runtime
  install_toolkit: true                     # Install Container Toolkit
  configure_containerd: true                # Configure containerd
  create_runtime_class: true                # Create RuntimeClass
```

#### Network and Runtime Settings
```yaml
network_plugin: calico                      # CNI plugin (calico, flannel, etc.)
container_runtime: containerd               # Container runtime
dns_mode: coredns                          # DNS service
```

### 2. Helm Charts Configuration

#### Infrastructure Components

**GPU Operator (v25.3.0)**
```yaml
gpu_operator_chart:
  release_name: gpu-operator
  chart_ref: gpu-operator
  release_namespace: gpu-operator
  chart_version: v25.3.0
  release_values:
    mig:
      strategy: none
    dcgm:
      enabled: true
    driver:
      enabled: false                        # Assumes drivers pre-installed
```

**Prometheus Stack (v55.5.0)**
```yaml
prometheus_stack:
  release_name: prometheus
  chart_ref: kube-prometheus-stack
  release_namespace: monitoring
  chart_version: "55.5.0"
  release_values:
    kubeEtcd:
      enabled: false
    prometheus:
      prometheusSpec:
        retention: 15d
        additionalScrapeConfigs:
          - job_name: gpu-metrics
            scrape_interval: 1s
            # GPU metrics collection configuration
    grafana:
      enabled: true
      persistence:
        enabled: true
        size: 1Gi
```

**KEDA (v2.12.1)**
```yaml
keda_chart:
  release_name: keda
  chart_ref: keda
  release_namespace: keda
  chart_version: "2.12.1"
```

**NIM Operator (v1.0.1)**
```yaml
nim_operator_chart:
  release_name: nim
  chart_ref: k8s-nim-operator
  release_namespace: nim
  chart_version: "v1.0.1"
```

### 3. Manifests Configuration

#### Infrastructure Manifests

**Pushgateway**
```yaml
pushgateway_manifest:
  name: pushgateway-setup
  manifest_file: "files/pushgateway.yaml"
  namespace: monitoring
  wait: true
  wait_timeout: 300
  validate: true
  strict_validation: true
```

#### AI/ML Manifests

**NIM Cache**
```yaml
nim_cache_manifest:
  name: nim-cache-setup
  manifest_file: "files/nim-cache.yaml.j2"
  namespace: nim
  wait_timeout: 600
  variables:
    nim_cache_name: "meta-llama3-8b-instruct"
    nim_cache_model_puller: "nvcr.io/nim/meta/llama-3.1-8b-instruct:1.8.4"
    nim_cache_pull_secret: "ngc-secret"
    nim_cache_auth_secret: "ngc-api-secret"
    nim_cache_model_engine: "vllm"
    nim_cache_tensor_parallelism: "1"
    nim_cache_qos_profile: "throughput"
    nim_cache_model_profiles:
      - "4f904d571fe60ff24695b5ee2aa42da58cb460787a968f1e8a09f5a7e862728d"
    nim_cache_pvc_create: true
    nim_cache_storage_class: "local-path"
    nim_cache_pvc_size: "200Gi"
```

**NIM Service**
```yaml
nim_service_manifest:
  name: nim-service-setup
  manifest_file: "files/nim-service.yaml.j2"
  namespace: nim
  variables:
    nim_service_name: "meta-llama3-8b-instruct"
    nim_service_image_repository: "nvcr.io/nim/meta/llama-3.1-8b-instruct"
    nim_service_image_tag: "1.8.4"
    nim_service_env:
      - name: "LOG_LEVEL"
        value: "INFO"
      - name: "VLLM_LOG_LEVEL"
        value: "INFO"
      - name: "NIM_LOG_LEVEL"
        value: "INFO"
      - name: "OMP_NUM_THREADS"
        value: "8"
      - name: "MAX_NUM_SEQS"
        value: "128"
    nim_service_metrics:
      enabled: true
      service_monitor:
        additional_labels:
          release: "prometheus"
    nim_service_replicas: 1
    nim_service_resources:
      limits:
        nvidia.com/gpu: 1
    nim_service_expose_type: "ClusterIP"
    nim_service_expose_port: 8000
```

#### Smart Scaler Manifests

**KEDA ScaledObject**
```yaml
keda_scaled_object_manifest:
  name: keda-scaled-object-setup
  manifest_file: "files/keda-scaled-object.yaml.j2"
  namespace: nim
  variables:
    keda_scaled_object_name: "llm-demo-keda"
    keda_scaled_object_target_name: "meta-llama3-8b-instruct"
    keda_scaled_object_polling_interval: 30
    keda_scaled_object_min_replicas: 1
    keda_scaled_object_max_replicas: 8
    keda_scaled_object_prometheus_address: "http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090"
    keda_scaled_object_metric_name: "smartscaler_hpa_num_pods"
    keda_scaled_object_threshold: "1"
    keda_scaled_object_query: >-
      smartscaler_hpa_num_pods{job="pushgateway", kubernetes_pod_name="meta-llama3-8b-instruct->nim->nim-llama", ss_deployment_name="meta-llama3-8b-instruct"}
```

**Smart Scaler Inference**
```yaml
smart_scaler_inference:
  name: smart-scaler-inference-setup
  manifest_file: "files/smart-scaler-inference.yaml.j2"
  namespace: smart-scaler
  variables:
    smart_scaler_name: "smart-scaler-llm-inf"
    smart_scaler_labels:
      service: "inference-tenant-app"
      cluster_name: "nim-llama"
      tenant_id: "tenant-b200-local"
      app_name: "nim-llama"
      app_version: "1.0"
    smart_scaler_image: "aveshasystems/smart-scaler-llm-inference-benchmark:v1.0.0"
    smart_scaler_args:
      - "wandb disabled && python policy/inference_script.py -c /data/config-inference.json --restore -p ./checkpoint_000052 --mode mesh --no-smartscalerdb --no-cpu-switch --inference-session sess-llama-3-1-14-May"
    smart_scaler_resources:
      requests:
        memory: "1.5Gi"
        cpu: "100m"
    smart_scaler_ports: [9900, 8265, 4321, 6379]
    smart_scaler_image_pull_secret: "avesha-systems"
```

#### Load Testing Manifests

**Locust**
```yaml
locust_manifest:
  name: locust-setup
  manifest_file: "files/locust-deploy.yaml.j2"
  namespace: nim-load-test
  variables:
    locust_name: "locust-load"
    locust_replicas: 1
    locust_image: "locustio/locust:2.15.1"
    locust_target_host: "http://meta-llama3-8b-instruct.nim.svc.cluster.local:8000"
    locust_cpu_request: "1"
    locust_memory_request: "1Gi"
    locust_cpu_limit: "2"
    locust_memory_limit: "2Gi"
    locust_configmap_name: "locustfile"
```

### 4. Command Execution Configuration

The command execution section handles secret management and ConfigMap creation:

#### NGC Secret Management
```yaml
- name: "create_ngc_secrets"
  kubeconfig: "{{ kubeconfig | default(global_kubeconfig) }}"
  kubecontext: "{{ kubecontext | default(global_kubecontext) }}"
  commands:
    - cmd: |
        kubectl create secret docker-registry ngc-secret \
          --docker-server=nvcr.io \
          --docker-username='$oauthtoken' \
          --docker-password="${NGC_DOCKER_API_KEY}" \
          --docker-email='your.email@solo.io' \
          -n nim
      env:
        NGC_DOCKER_API_KEY: "{{ ngc_docker_api_key }}"
```

#### Avesha Secret Management
```yaml
- name: "create_avesha_secret"
  commands:
    - cmd: |
        kubectl create secret docker-registry avesha-systems \
          --docker-username="${AVESHA_DOCKER_USERNAME}" \
          --docker-password="${AVESHA_DOCKER_PASSWORD}" \
          -n smart-scaler
      env:
        AVESHA_DOCKER_USERNAME: "{{ avesha_docker_username }}"
        AVESHA_DOCKER_PASSWORD: "{{ avesha_docker_password }}"
```

#### ConfigMap Management
```yaml
- name: "create_inference_pod_configmap"
  commands:
    - cmd: |
        kubectl create configmap -n smart-scaler mesh-config \
          --from-file=files/config-inference.json

- name: "create_locust_configmap"
  commands:
    - cmd: |
        kubectl create configmap -n nim-load-test locustfile \
          --from-file=locustfile.py=files/locust.py
```

## Usage Examples

### 1. Complete Platform Deployment

For a full Smart Scaler platform deployment:

```yaml
kubernetes_deployment:
  enabled: true
  firewall:
    enabled: true
  nvidia_runtime:
    enabled: true
    install_toolkit: true
    configure_containerd: true
    create_runtime_class: true

execution_order:
  - gpu_operator_chart
  - prometheus_stack
  - pushgateway_manifest
  - keda_chart
  - nim_operator_chart
  - create_ngc_secrets
  - verify_ngc_secrets
  - create_avesha_secret
  - nim_cache_manifest
  - nim_service_manifest
  - keda_scaled_object_manifest
  - create_inference_pod_configmap
  - smart_scaler_inference
  - create_locust_configmap
  - locust_manifest
```

### 2. Infrastructure Only Deployment

For infrastructure components only:

```yaml
execution_order:
  - gpu_operator_chart
  - prometheus_stack
  - pushgateway_manifest
  - keda_chart
```

### 3. AI/ML Platform Only

For AI/ML components without Smart Scaler:

```yaml
execution_order:
  - nim_operator_chart
  - create_ngc_secrets
  - verify_ngc_secrets
  - nim_cache_manifest
  - nim_service_manifest
```

## Environment Variables

The following environment variables must be set before deployment:

```bash
# NGC API Credentials (Required for NVIDIA components)
export NGC_API_KEY="your-ngc-api-key"
export NGC_DOCKER_API_KEY="your-ngc-docker-api-key"

# Avesha Systems Docker Registry Credentials (Required for Smart Scaler)
export AVESHA_DOCKER_USERNAME="your-avesha-username"
export AVESHA_DOCKER_PASSWORD="your-avesha-password"
```

## Best Practices

### 1. Configuration Management
- Always validate your `user_input.yml` before deployment
- Use environment variables for sensitive data
- Keep backup copies of working configurations

### 2. Security
- Never commit sensitive data to version control
- Use proper RBAC configurations
- Regularly rotate secrets and credentials

### 3. Resource Management
- Set appropriate resource limits and requests
- Monitor GPU utilization and scaling metrics
- Plan for storage requirements (especially for NIM Cache)

### 4. Deployment Strategy
- Test deployments in development environment first
- Use step-by-step deployment for troubleshooting
- Monitor each component before proceeding to the next

### 5. Troubleshooting
- Use verbose output for debugging: `ansible-playbook site.yml -vvvv`
- Check individual component status after each deployment step
- Verify environment variables and secrets before deployment

## Related Documentation

- [Kubernetes Configuration](KUBERNETES_CONFIGURATION.md) - Detailed Kubernetes cluster setup
- [User Input Reference](USER_INPUT_REFERENCE.md) - Complete configuration reference
- [NVIDIA Container Runtime](NVIDIA_CONTAINER_RUNTIME.md) - GPU runtime configuration
- [Kubernetes Firewall](KUBERNETES_FIREWALL.md) - Network security configuration 