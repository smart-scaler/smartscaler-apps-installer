# User Input Configuration Reference

This document provides a detailed reference for all configuration options in the `user_input.yml` file for the Smart Scaler platform deployment.

## Table of Contents

1. [Kubernetes Deployment](#kubernetes-deployment)
2. [Global Settings](#global-settings)
3. [Environment Variables](#environment-variables)
4. [Execution Configuration](#execution-configuration)
5. [Helm Charts](#helm-charts)
6. [Manifests](#manifests)
7. [Command Execution](#command-execution)

## Kubernetes Deployment

```yaml
kubernetes_deployment:
  enabled: false                               # Enable/disable Kubernetes cluster deployment
  
  # Firewall Configuration
  firewall:
    enabled: true                             # Enable/disable firewall configuration
    allow_additional_ports: []                # Additional ports to allow (e.g., ["8080", "9090"])
    
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
  network_plugin: calico                      # CNI plugin for pod networking (calico, flannel, weave, cilium)
  container_runtime: containerd               # Container runtime (containerd, crio)
  dns_mode: coredns                          # DNS mode (coredns, nodelocaldns)
```

### SSH Key Requirements

- The `ssh_key_path` MUST be an absolute path
- Example valid path: `/root/.ssh/k8s_rsa`
- Example invalid path: `~/.ssh/k8s_rsa`
- Key permissions must be set to 600: `chmod 600 /path/to/key`

### Firewall Configuration

```yaml
firewall:
  enabled: true                             # Enable automatic firewall management
  allow_additional_ports:                   # Additional ports to open
    - "8080"                               # Custom HTTP port
    - "9090"                               # Custom metrics port
    - "3000"                               # Grafana port
```

### NVIDIA Runtime Configuration

```yaml
nvidia_runtime:
  enabled: true                            # Enable NVIDIA runtime support
  install_toolkit: true                     # Install NVIDIA Container Toolkit
  configure_containerd: true                # Configure containerd for GPU support
  create_runtime_class: true                # Create Kubernetes RuntimeClass
```

### Node Configuration

Each node in `control_plane_nodes` supports:
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
global_kubecontext: "kubecontext"             # Kubernetes context to use
use_global_context: true                      # Use global context for all operations

# Helm configuration
use_local_charts: false                       # Use local chart files instead of remote repos
local_charts_path: "charts"                   # Path to local charts if use_local_charts is true
global_chart_repo_url: ""                     # Default Helm repository URL
global_repo_username: ""                      # Helm repository username
global_repo_password: ""                      # Helm repository password
readd_helm_repos: true                        # Re-add Helm repos even if they exist
```

## Environment Variables

```yaml
# NGC credentials (for NVIDIA components)
ngc_api_key: "{{ lookup('env', 'NGC_API_KEY') }}"
ngc_docker_api_key: "{{ lookup('env', 'NGC_DOCKER_API_KEY') }}"

# Avesha credentials (for Smart Scaler components)
avesha_docker_username: "{{ lookup('env', 'AVESHA_DOCKER_USERNAME') }}"
avesha_docker_password: "{{ lookup('env', 'AVESHA_DOCKER_PASSWORD') }}"
```

Required environment variables:
- `NGC_API_KEY`: NVIDIA NGC API key
- `NGC_DOCKER_API_KEY`: NVIDIA Docker registry API key
- `AVESHA_DOCKER_USERNAME`: Avesha Docker registry username
- `AVESHA_DOCKER_PASSWORD`: Avesha Docker registry password

## Execution Configuration

```yaml
# Validation Configuration
validate_prerequisites:
  enabled: true                            # Enable prerequisite validation

# Execution Configuration
execution_order_enabled: true               # Enable/disable execution order tasks

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

## Helm Charts

### Infrastructure Components

#### GPU Operator (v25.3.0)

```yaml
gpu_operator_chart:
  release_name: gpu-operator           # Helm release name
  chart_ref: gpu-operator             # Chart reference
  release_namespace: gpu-operator     # Target namespace
  create_namespace: true             # Create namespace if it doesn't exist
  wait: true                         # Wait for deployment completion
  chart_version: v25.3.0            # Chart version to install
  chart_repo_url: "https://helm.ngc.nvidia.com/nvidia"  # NVIDIA Helm repository
  release_values:                    # Chart-specific values
    mig:
      strategy: none                 # MIG strategy (none, single, mixed)
    dcgm:
      enabled: true                  # Enable DCGM for GPU monitoring
    driver:
      enabled: false                # Disable driver installation (assumes pre-installed)
```

#### Prometheus Stack (v55.5.0)

```yaml
prometheus_stack:
  release_name: prometheus
  chart_ref: kube-prometheus-stack
  release_namespace: monitoring
  create_namespace: true
  wait: true
  chart_repo_url: "https://prometheus-community.github.io/helm-charts"
  chart_version: "55.5.0"
  release_values:
    kubeEtcd:
      enabled: false              # Disable etcd monitoring
    prometheus:
      prometheusSpec:
        retention: 15d              # Data retention period
        additionalScrapeConfigs:    # Additional scrape configurations
          - job_name: gpu-metrics   # GPU metrics collection
            scrape_interval: 1s
            metrics_path: /metrics
            scheme: http
            kubernetes_sd_configs:
              - role: endpoints
                namespaces:
                  names:
                    - monitoring
                    - gpu-operator
    prometheusOperator:
      enabled: true
      admissionWebhooks:
        enabled: true
        patch:
          enabled: true
    kubelet:
      serviceMonitor:
        https: false
    grafana:
      enabled: true
      persistence:
        enabled: true
        size: 1Gi
    defaultRules:
      rules:
        etcd: false
```

#### KEDA (v2.12.1)

```yaml
keda_chart:
  release_name: keda
  chart_ref: keda
  release_namespace: keda
  create_namespace: true
  wait: true
  chart_repo_url: "https://kedacore.github.io/charts"
  chart_version: "2.12.1"
```

#### NIM Operator (v1.0.1)

```yaml
nim_operator_chart:
  release_name: nim
  chart_ref: k8s-nim-operator
  release_namespace: nim
  create_namespace: true
  wait: true
  chart_repo_url: "https://helm.ngc.nvidia.com/nvidia"
  chart_version: "v1.0.1"
```

## Manifests

### Infrastructure Manifests

#### Pushgateway

```yaml
pushgateway_manifest:
  name: pushgateway-setup             # Manifest name
  manifest_file: "files/pushgateway.yaml"  # Template file
  namespace: monitoring               # Target namespace
  kubeconfig: "{{ kubeconfig | default(global_kubeconfig) }}"
  kubecontext: "{{ kubecontext | default(global_kubecontext) }}"
  variables:
    namespace: monitoring
  wait: true
  wait_timeout: 300
  wait_condition:
    type: Available
    status: "True"
  validate: true
  strict_validation: true
```

### AI/ML Manifests

#### NIM Cache

```yaml
nim_cache_manifest:
  name: nim-cache-setup
  manifest_file: "files/nim-cache.yaml.j2"
  namespace: nim
  kubeconfig: "{{ kubeconfig | default(global_kubeconfig) }}"
  kubecontext: "{{ kubecontext | default(global_kubecontext) }}"
  wait: true
  wait_timeout: 600
  wait_condition:
    type: Available
    status: "True"
  validate: true
  strict_validation: true
  variables:
    nim_cache_name: "meta-llama3-8b-instruct"         # Cache resource name
    nim_cache_namespace: "nim"                         # Namespace
    nim_cache_runtime_class: "nvidia"                 # Runtime class
    nim_cache_tolerations:                             # Node tolerations
      - key: "nvidia.com/gpu"
        operator: "Exists"
        effect: "NoSchedule"
    nim_cache_model_puller: "nvcr.io/nim/meta/llama-3.1-8b-instruct:1.8.4"  # Model image
    nim_cache_pull_secret: "ngc-secret"               # Docker pull secret
    nim_cache_auth_secret: "ngc-api-secret"           # API authentication secret
    nim_cache_model_engine: "vllm"                    # Model engine
    nim_cache_tensor_parallelism: "1"                 # Tensor parallelism degree
    nim_cache_qos_profile: "throughput"               # QoS profile
    nim_cache_model_profiles:                         # Model profile IDs
      - "4f904d571fe60ff24695b5ee2aa42da58cb460787a968f1e8a09f5a7e862728d"
    nim_cache_pvc_create: true                        # Create PVC
    nim_cache_storage_class: "local-path"             # Storage class
    nim_cache_pvc_size: "200Gi"                       # PVC size
    nim_cache_volume_access_mode: "ReadWriteOnce"     # Volume access mode
    nim_cache_resources: {}                           # Resource constraints
```

#### NIM Service

```yaml
nim_service_manifest:
  name: nim-service-setup
  manifest_file: "files/nim-service.yaml.j2"
  namespace: nim
  wait: true
  wait_timeout: 600
  variables:
    nim_service_name: "meta-llama3-8b-instruct"      # Service name
    nim_service_namespace: "nim"                      # Namespace
    nim_service_runtime_class: "nvidia"              # Runtime class
    nim_service_env:                                  # Environment variables
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
    nim_service_tolerations:                          # Node tolerations
      - key: "nvidia.com/gpu"
        operator: "Exists"
        effect: "NoSchedule"
    nim_service_image_repository: "nvcr.io/nim/meta/llama-3.1-8b-instruct"  # Image repository
    nim_service_image_tag: "1.8.4"                   # Image tag
    nim_service_image_pull_policy: "IfNotPresent"    # Pull policy
    nim_service_image_pull_secrets:                   # Pull secrets
      - "ngc-secret"
    nim_service_auth_secret: "ngc-api-secret"        # Auth secret
    nim_service_metrics:                              # Metrics configuration
      enabled: true
      service_monitor:
        additional_labels:
          release: "prometheus"
    nim_service_storage_cache_name: "meta-llama3-8b-instruct"              # Cache name
    nim_service_storage_cache_profile: "4f904d571fe60ff24695b5ee2aa42da58cb460787a968f1e8a09f5a7e862728d"  # Cache profile
    nim_service_replicas: 1                           # Number of replicas
    nim_service_resources:                            # Resource requests/limits
      limits:
        nvidia.com/gpu: 1
    nim_service_expose_type: "ClusterIP"             # Service type
    nim_service_expose_port: 8000                    # Service port
```

### Smart Scaler Manifests

#### KEDA ScaledObject

```yaml
keda_scaled_object_manifest:
  name: keda-scaled-object-setup
  manifest_file: "files/keda-scaled-object.yaml.j2"
  namespace: nim
  variables:
    keda_scaled_object_name: "llm-demo-keda"         # ScaledObject name
    keda_scaled_object_namespace: "nim"              # Namespace
    keda_scaled_object_target_name: "meta-llama3-8b-instruct"  # Target deployment
    keda_scaled_object_polling_interval: 30          # Polling interval (seconds)
    keda_scaled_object_min_replicas: 1               # Minimum replicas
    keda_scaled_object_max_replicas: 8               # Maximum replicas
    keda_scaled_object_prometheus_address: "http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090"  # Prometheus URL
    keda_scaled_object_metric_name: "smartscaler_hpa_num_pods"  # Metric name
    keda_scaled_object_threshold: "1"                # Scaling threshold
    keda_scaled_object_query: >-                     # Prometheus query
      smartscaler_hpa_num_pods{job="pushgateway", kubernetes_pod_name="meta-llama3-8b-instruct->nim->nim-llama", ss_deployment_name="meta-llama3-8b-instruct"}
```

#### Smart Scaler Inference

```yaml
smart_scaler_inference:
  name: smart-scaler-inference-setup
  manifest_file: "files/smart-scaler-inference.yaml.j2"
  namespace: smart-scaler
  variables:
    smart_scaler_name: "smart-scaler-llm-inf"       # Deployment name
    smart_scaler_namespace: "smart-scaler"          # Namespace
    smart_scaler_labels:                             # Pod labels
      service: "inference-tenant-app"
      cluster_name: "nim-llama"
      tenant_id: "tenant-b200-local"
      app_name: "nim-llama"
      app_version: "1.0"
    smart_scaler_tolerations:                        # Node tolerations
      - key: "nvidia.com/gpu"
        operator: "Exists"
        effect: "NoSchedule"
    smart_scaler_resources:                          # Resource requirements
      requests:
        memory: "1.5Gi"
        cpu: "100m"
    smart_scaler_replicas: 1                         # Number of replicas
    smart_scaler_automount_sa: true                  # Automount service account
    smart_scaler_restart_policy: "Always"           # Restart policy
    smart_scaler_config_volume_name: "data"         # Config volume name
    smart_scaler_config_map_name: "mesh-config"     # ConfigMap name
    smart_scaler_container_name: "inference"        # Container name
    smart_scaler_image: "aveshasystems/smart-scaler-llm-inference-benchmark:v1.0.0"  # Image
    smart_scaler_image_pull_policy: "IfNotPresent"  # Pull policy
    smart_scaler_command: ["/bin/sh", "-c"]         # Container command
    smart_scaler_args:                               # Container arguments
      - "wandb disabled && python policy/inference_script.py -c /data/config-inference.json --restore -p ./checkpoint_000052 --mode mesh --no-smartscalerdb --no-cpu-switch --inference-session sess-llama-3-1-14-May"
    smart_scaler_config_mount_path: "/data"         # Config mount path
    smart_scaler_ports: [9900, 8265, 4321, 6379]   # Exposed ports
    smart_scaler_image_pull_secret: "avesha-systems"  # Pull secret
```

### Load Testing Manifests

#### Locust

```yaml
locust_manifest:
  name: locust-setup
  manifest_file: "files/locust-deploy.yaml.j2"
  namespace: nim-load-test
  variables:
    locust_name: "locust-load"                       # Deployment name
    locust_namespace: "nim-load-test"                # Namespace
    locust_replicas: 1                               # Number of replicas
    locust_image: "locustio/locust:2.15.1"          # Locust image
    locust_target_host: "http://meta-llama3-8b-instruct.nim.svc.cluster.local:8000"  # Target host
    locust_cpu_request: "1"                          # CPU request
    locust_memory_request: "1Gi"                     # Memory request
    locust_cpu_limit: "2"                            # CPU limit
    locust_memory_limit: "2Gi"                       # Memory limit
    locust_configmap_name: "locustfile"              # ConfigMap name
```

## Command Execution

### NGC Secret Management

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
        KUBECONFIG: "{{ kubeconfig | default(global_kubeconfig) }}"
    
    - cmd: |
        kubectl create secret generic ngc-api-secret -n nim \
          --from-literal=NGC_API_KEY="${NGC_API_KEY}"
      env:
        NGC_API_KEY: "{{ ngc_api_key }}"
        KUBECONFIG: "{{ kubeconfig | default(global_kubeconfig) }}"

- name: "verify_ngc_secrets"
  commands:
    - cmd: "kubectl get secret ngc-secret -n nim -o jsonpath={.metadata.name}"
      env:
        KUBECONFIG: "{{ global_kubeconfig }}"
        KUBECONTEXT: "{{ global_kubecontext }}"
      ignore_errors: true
    - cmd: "kubectl get secret ngc-api-secret -n nim -o jsonpath={.metadata.name}"
      env:
        KUBECONFIG: "{{ global_kubeconfig }}"
        KUBECONTEXT: "{{ global_kubecontext }}"
      ignore_errors: true
```

### Avesha Secret Management

```yaml
- name: "create_avesha_secret"
  kubeconfig: "{{ kubeconfig | default(global_kubeconfig) }}"
  kubecontext: "{{ kubecontext | default(global_kubecontext) }}"
  commands:
    - cmd: |
        kubectl create secret docker-registry avesha-systems \
          --docker-username="${AVESHA_DOCKER_USERNAME}" \
          --docker-password="${AVESHA_DOCKER_PASSWORD}" \
          -n smart-scaler
      env:
        AVESHA_DOCKER_USERNAME: "{{ avesha_docker_username }}"
        AVESHA_DOCKER_PASSWORD: "{{ avesha_docker_password }}"
        KUBECONFIG: "{{ kubeconfig | default(global_kubeconfig) }}"

- name: "verify_avesha_secret"
  commands:
    - cmd: "kubectl get secret avesha-systems -n smart-scaler -o jsonpath={.metadata.name}"
      env:
        KUBECONFIG: "{{ global_kubeconfig }}"
        KUBECONTEXT: "{{ global_kubecontext }}"
      ignore_errors: true
```

### ConfigMap Management

```yaml
- name: "create_inference_pod_configmap"
  kubeconfig: "{{ kubeconfig | default(global_kubeconfig) }}"
  kubecontext: "{{ kubecontext | default(global_kubecontext) }}"
  commands:
    - cmd: |
        kubectl create namespace smart-scaler --dry-run=client -o yaml | \
        kubectl apply -f -
        kubectl create configmap -n smart-scaler mesh-config \
          --from-file=files/config-inference.json

- name: "create_locust_configmap"
  kubeconfig: "{{ kubeconfig | default(global_kubeconfig) }}"
  kubecontext: "{{ kubecontext | default(global_kubecontext) }}"
  commands:
    - cmd: |
        kubectl create namespace nim-load-test --dry-run=client -o yaml | \
        kubectl apply -f -
        kubectl create configmap -n nim-load-test locustfile \
          --from-file=locustfile.py=files/locust.py
```

## Common Configuration Patterns

### Helm Chart Configuration

Each Helm chart in the `helm_charts` section supports:
- `release_name`: Name of the Helm release
- `chart_ref`: Chart name/reference
- `release_namespace`: Kubernetes namespace
- `create_namespace`: Whether to create the namespace
- `wait`: Wait for deployment completion
- `chart_version`: Specific chart version
- `chart_repo_url`: Chart repository URL
- `release_values`: Chart-specific values

### Manifest Configuration

Each manifest in the `manifests` section supports:
- `name`: Manifest identifier
- `manifest_file`: Path to the template file
- `namespace`: Target namespace
- `kubeconfig`: Kubeconfig file to use
- `kubecontext`: Kubernetes context to use
- `wait`: Wait for resource readiness
- `wait_timeout`: Timeout for wait operations
- `wait_condition`: Condition to wait for
- `validate`: Enable manifest validation
- `strict_validation`: Enable strict validation
- `variables`: Template variables

### Command Execution Configuration

Each command in the `command_exec` section supports:
- `name`: Command identifier
- `kubeconfig`: Kubeconfig file to use
- `kubecontext`: Kubernetes context to use
- `commands`: List of commands to execute
  - `cmd`: Shell command to run
  - `env`: Environment variables
  - `ignore_errors`: Whether to ignore command failures

## Validation and Error Handling

- Set `validate_prerequisites.enabled: true` to enable prerequisite validation
- Use `ignore_errors: true` in commands to continue on failures
- Set appropriate `wait_timeout` values for long-running deployments
- Use `strict_validation: true` for enhanced manifest validation

## Related Documentation

- [Kubernetes Configuration](KUBERNETES_CONFIGURATION.md) - Detailed Kubernetes cluster setup
- [User Input Configuration Guide](USER_INPUT_CONFIGURATION.md) - Configuration guide with examples
- [NVIDIA Container Runtime](NVIDIA_CONTAINER_RUNTIME.md) - GPU runtime configuration
- [Kubernetes Firewall](KUBERNETES_FIREWALL.md) - Network security configuration 