# Smart Scaler Apps Installer

Ansible-based installer for Smart Scaler components and dependencies.

## Prerequisites

Before running the installer, ensure you have:

1. Kubernetes cluster access with proper permissions
2. `kubectl` installed and configured
3. `helm` v3.x installed
4. NGC API credentials (API key and Docker API key)
5. AVESHA Docker Credentials 
6. Python 3.x and pip installed

### Setting Up Python Environment

1. Create and activate a virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate  # On Linux/Mac
# or
.\venv\Scripts\activate  # On Windows
```

2. Install Python dependencies:
```bash
# Install Python packages
pip install -r requirements.txt

# The requirements include:
# - ansible>=2.10
# - openshift
# - kubernetes
# - PyYAML
# - kubernetes-validate>=1.28.0
```

### Installing Ansible Collections

Install required Ansible collections from Galaxy:
```bash
# Install collections from requirements.yml
ansible-galaxy collection install -r requirements.yml

# Collections included:
# - community.general
# - kubernetes.core
```

### Verifying Installation

Verify the installation of required components:
```bash
# Check Python packages
pip list | grep -E "ansible|kubernetes|openshift|PyYAML"

# Check Ansible collections
ansible-galaxy collection list | grep -E "community.general|kubernetes.core"

# Check kubectl version
kubectl version --client

# Check helm version
helm version
```

## Detailed Documentation

## Ansible Project Structure

```
smartscaler-apps-installer/
├── ansible.cfg                 # Ansible configuration
├── site.yml                   # Main playbook entry point
├── kubernetes.yml              # Kubernetes-specific playbook
├── user_input.yml             # User configuration file
├── requirements.txt            # Python package dependencies
├── requirements.yml            # Ansible Galaxy collections
├── setup_kubernetes.sh         # Kubernetes setup automation script
├── .gitignore                  # Git ignore rules
├── .gitmodules                 # Git submodules configuration
│
├── inventory/                  # Ansible inventory management
│   └── hosts                  # Static inventory file
│
├── group_vars/                 # Group-level variables
│   └── all/                   # Variables for all hosts
│       ├── main.yml          # Common variables
│       └── vault.yml         # Encrypted sensitive data
│
├── host_vars/                  # Host-specific variables
│
├── roles/                      # Ansible roles for component management
│   ├── helm_chart_install/    # Helm chart installation role
│   │   ├── tasks/            # Role tasks
│   │   └── templates/        # Jinja2 templates
│   ├── manifest_install/      # Kubernetes manifest installation role
│   ├── command_exec/          # Shell command execution role
│   └── kubernetes/            # Kubernetes setup role
│
├── tasks/                      # Shared task files
│   ├── process_execution_item.yml     # Task execution handler
│   ├── process_execution_order.yml    # Main execution orchestrator
│   └── validate_prerequisites.yml     # Prerequisite validation
│
├── templates/                  # Jinja2 template files
│
├── files/                      # Static files and manifests
│   ├── kubeconfig             # Kubernetes configuration
│   ├── pushgateway.yaml       # Pushgateway manifest
│   ├── nim-cache.yaml.j2      # NIM Cache parameterized template
│   ├── nim-service.yaml.j2    # NIM Service deployment template
│   ├── keda-scaled-object.yaml.j2 # KEDA ScaledObject template
│   ├── smart-scaler-inference.yaml.j2 # Smart Scaler inference app template
│   ├── locust-deploy.yaml.j2  # Locust load testing deployment template
│   ├── config-inference.json  # Smart Scaler inference configuration
│   └── locust.py             # Locust load testing script
│
├── collections/                # Ansible collections
├── kubespray/                 # Kubespray submodule for K8s installation
│
└── docs/                      # Documentation directory
    ├── KUBERNETES_CONFIGURATION.md
    ├── KUBERNETES_FIREWALL.md
    ├── NVIDIA_CONTAINER_RUNTIME.md
    ├── USER_INPUT_CONFIGURATION.md
    └── USER_INPUT_REFERENCE.md
```

## Documentation Links

### Core Configuration Guides
- **[User Input Configuration Guide](docs/USER_INPUT_CONFIGURATION.md)** - Complete guide for configuring user_input.yml
- **[User Input Reference](docs/USER_INPUT_REFERENCE.md)** - Reference documentation for all configuration options
- **[Kubernetes Configuration](docs/KUBERNETES_CONFIGURATION.md)** - Kubernetes cluster setup and configuration
- **[Kubernetes Firewall Configuration](docs/KUBERNETES_FIREWALL.md)** - Network and firewall setup for Kubernetes

### Specialized Configuration
- **[NVIDIA Container Runtime Configuration](docs/NVIDIA_CONTAINER_RUNTIME.md)** - GPU runtime setup and configuration

### Quick Reference Links
- [Prerequisites](#prerequisites)
- [Environment Variables](#required-environment-variables)
- [K8s Setup Guide](#part-1-kubernetes-cluster-setup)
- [Apps Deployment Guide](#part-2-smart-scaler-applications-deployment)
- [Troubleshooting Guide](#troubleshooting)
- [Contributing Guidelines](#contributing)

---

# Part 1: Kubernetes Cluster Setup

## Prerequisites

Before setting up the Kubernetes cluster, ensure you have:

1. **System Requirements**
    #### Control Plane Nodes (Master)
    - CPU: 8 cores minimum
    - RAM: 16GB minimum
    - Storage: 500GB minimum
    - Operating System: Ubuntu 22.04+ or compatible Linux distribution
    
    #### Worker Nodes
    - CPU: 8 cores minimum
    - RAM: 16GB minimum
    - Storage: 500GB minimum
    - Operating System: Same as control plane nodes

2. **Local Development Environment**
   - Python 3.x and pip installed
   - Git installed
   - SSH key generation capability

3. **NVIDIA GPU Requirements** (for GPU nodes)
   - NVIDIA GPU drivers installed
   - Docker runtime configured for GPU support

### Setting Up Local Environment

1. **Clone the repository:**
```bash
git clone https://github.com/smart-scaler/smartscaler-apps-installer.git
cd smartscaler-apps-installer
```

2. **Create and activate a virtual environment:**
```bash
python3 -m venv venv
source venv/bin/activate  # On Linux/Mac
# or
.\venv\Scripts\activate  # On Windows
```

3. **Install Python dependencies:**
```bash
pip install -r requirements.txt

# The requirements include:
# - ansible>=2.10
# - openshift
# - kubernetes
# - PyYAML
# - kubernetes-validate>=1.28.0
```

4. **Install Ansible collections:**
```bash
ansible-galaxy collection install -r requirements.yml

# Collections installed:
#  - community.general
#  - kubernetes.core
#  - ansible.posix
#  - community.crypto 
```

### SSH Key Setup

1. **Generate SSH key for cluster access:**
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/k8s_rsa -N ""
```

2. **Copy SSH key to each node:**
```bash
# Repeat for each node in your cluster
ssh-copy-id -i ~/.ssh/k8s_rsa.pub user@node-ip
```

### Verifying Installation

```bash
# Check Python packages
pip list | grep -E "ansible|kubernetes|openshift|PyYAML"

# Check Ansible collections
ansible-galaxy collection list | grep -E "community.general|kubernetes.core"

# Check kubectl version (if already installed)
kubectl version --client

# Check helm version (if already installed)
helm version
```

## Kubernetes Cluster Installation

⚠️ **IMPORTANT**: The **ONLY** supported method for installing Kubernetes is through the `setup_kubernetes.sh` script.

### Configuration

1. **Update node IPs in `user_input.yml`:**
```yaml
kubernetes_deployment:
  enabled: true  # Must be set to true for K8s installation
  
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
      ansible_host: "YOUR_MASTER_NODE_IP"     # IP address or DNS name of the node
      ansible_user: root                      # SSH user for this specific node
      ansible_become: true
      ansible_become_method: sudo
      private_ip: 10.0.0.19

  
  # Kubernetes Components Configuration
  network_plugin: calico                      # CNI plugin for pod networking (options: calico, flannel, etc.)
  container_runtime: containerd               # Container runtime (options: containerd, docker)
  dns_mode: coredns                          # DNS service for the cluster
```

2. **SSH User Configuration:**
   
   **Option 1 (Recommended): Non-root user with sudo**
   ```yaml
   ansible_user: avesha
   ansible_become: true
   ansible_become_method: sudo
   ansible_become_user: root
   ```
   
   **Option 2: Direct root access**
   ```yaml
   ansible_user: root
   ```

### Installation Process

1. **Execute the Kubernetes setup script:**
```bash
chmod +x setup_kubernetes.sh
./setup_kubernetes.sh
```

The script will:
- Create an inventory.ini file for kubespray
- Validate your configuration
- Test SSH connectivity to all nodes
- Generate necessary inventory files
- Deploy Kubernetes components using kubespray
- Configure NVIDIA runtime if enabled
- Setup firewall rules if enabled
- Verify the installation

2. **Verify the installation:**
```bash
kubectl get nodes -o wide
kubectl cluster-info
kubectl get pods --all-namespaces
```

### Post-Installation Configuration

1. **Configure kubeconfig access:**
```bash
# Copy kubeconfig from master node
scp user@master-node-ip:/etc/kubernetes/admin.conf files/kubeconfig

# Update permissions
chmod 600 files/kubeconfig
```

2. **Update kubeconfig settings in user_input.yml:**
```yaml
global_kubeconfig: "files/kubeconfig"
global_kubecontext: "your-cluster-context"
```

3. **Verify cluster access:**
```bash
export KUBECONFIG=files/kubeconfig
kubectl get nodes
```

---

# Part 2: Smart Scaler Applications Deployment

## Required Environment Variables

Set up the following environment variables before deploying applications:

```bash
# NGC API Credentials (Required for NVIDIA components)
export NGC_API_KEY="your-ngc-api-key"
export NGC_DOCKER_API_KEY="your-ngc-docker-api-key"

# Avesha Systems Docker Registry Credentials
export AVESHA_DOCKER_USERNAME="your-avesha-username"
export AVESHA_DOCKER_PASSWORD="your-avesha-password"
```

## Components Overview

### Infrastructure Components

### 1. GPU Operator
- **Namespace**: `gpu-operator`
- **Chart**: `gpu-operator`
- **Version**: `v25.3.0`
- **Purpose**: NVIDIA GPU management and device plugin

### 2. Prometheus Stack
- **Namespace**: `monitoring`
- **Chart**: `kube-prometheus-stack`
- **Version**: `55.5.0`
- **Components**: Prometheus, Grafana, AlertManager
- **Features**: GPU metrics collection, custom dashboards

### 3. Pushgateway
- **Namespace**: `monitoring`
- **Type**: Custom manifest
- **Purpose**: Metrics aggregation for batch jobs and custom metrics

### 4. KEDA
- **Namespace**: `keda`
- **Chart**: `keda`
- **Version**: `2.12.1`
- **Purpose**: Kubernetes Event-driven Autoscaling

### AI/ML Components

### 5. NIM (NVIDIA NIM Operator)
- **Namespace**: `nim`
- **Chart**: `k8s-nim-operator`
- **Version**: `v1.0.1`
- **Purpose**: GPU instance management for AI workloads

### 6. NIM Cache
- **Namespace**: `nim`
- **Type**: Custom manifest
- **Purpose**: Download and prep LLM models with NIM Cache
- **Model**: Meta Llama 3.1 8B Instruct

### 7. NIM Service
- **Namespace**: `nim`
- **Type**: Custom manifest
- **Purpose**: Serve LLM models as REST API endpoints
- **Features**: GPU-optimized inference, metrics exposure

### Smart Scaler Components

### 8. Smart Scaler Inference
- **Namespace**: `smart-scaler`
- **Type**: Custom manifest
- **Purpose**: AI-driven inference optimization and scaling
- **Features**: Policy-based scaling, inference benchmarking

### 9. KEDA ScaledObject
- **Namespace**: `nim`
- **Type**: Custom manifest
- **Purpose**: Configure autoscaling for NIM services based on custom metrics
- **Metrics Source**: Prometheus via Smart Scaler

### Load Testing Components

### 10. Locust Load Testing
- **Namespace**: `nim-load-test`
- **Type**: Custom manifest
- **Purpose**: Generate load for testing and scaling validation
- **Target**: NIM service endpoints

## Application Configuration

### Updated Execution Order
The deployment follows this comprehensive execution order:

```yaml
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

### Helm Charts Configuration

#### GPU Operator Configuration
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
      enabled: false  # Assumes drivers are pre-installed
```

#### Prometheus Stack Configuration
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
            # ... GPU metrics collection configuration
    grafana:
      enabled: true
      persistence:
        enabled: true
        size: 1Gi
```

#### KEDA Configuration
```yaml
  keda_chart:
  release_name: keda
  chart_ref: keda
  release_namespace: keda
  chart_version: "2.12.1"
```

#### NIM Operator Configuration
```yaml
  nim_operator_chart:
  release_name: nim
  chart_ref: k8s-nim-operator
  release_namespace: nim
  chart_version: "v1.0.1"
```

### Advanced Manifest Configurations

#### NIM Cache Configuration
```yaml
nim_cache_manifest:
  name: nim-cache-setup
  manifest_file: "files/nim-cache.yaml.j2"
  namespace: nim
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

#### NIM Service Configuration
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

#### KEDA ScaledObject Configuration
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

#### Smart Scaler Inference Configuration
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
```

#### Locust Load Testing Configuration
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
```

## Application Deployment

### Prerequisites Verification
Before deploying applications, ensure:

1. **Kubernetes cluster is running**
```bash
kubectl get nodes
kubectl cluster-info
```

2. **Required tools are installed**
```bash
kubectl version --client
helm version
```

3. **Environment variables are set**
```bash
echo $NGC_API_KEY
echo $NGC_DOCKER_API_KEY
echo $AVESHA_DOCKER_USERNAME
echo $AVESHA_DOCKER_PASSWORD
```

4. **Required files are present**
```bash
ls -la files/
# Should contain:
# - kubeconfig
# - config-inference.json
# - locust.py
# - Various YAML templates
```

5. **Install Python 3.x and pip**
```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv
```

6. **Create and activate a virtual environment:**
```bash
python3 -m venv venv
source venv/bin/activate  # On Linux/Mac
# or
.\venv\Scripts\activate  # On Windows
```

7. **Install Python dependencies:**
```bash
pip install -r requirements.txt

# The requirements include:
# - ansible>=2.10
# - openshift
# - kubernetes
# - PyYAML
# - kubernetes-validate>=1.28.0
```

8. **Install Ansible collections:**
```bash
ansible-galaxy collection install -r requirements.yml

# Collections installed:
#  - community.general
#  - kubernetes.core
#  - ansible.posix
#  - community.crypto 
```

### Deployment Process


1. **Deployment with explicit credentials:**
```bash
ansible-playbook site.yml \
  -e "ngc_api_key=$NGC_API_KEY" \
  -e "ngc_docker_api_key=$NGC_DOCKER_API_KEY" \
  -e "avesha_docker_username=$AVESHA_DOCKER_USERNAME" \
  -e "avesha_docker_password=$AVESHA_DOCKER_PASSWORD"
```

2. **Debug deployment with verbose output:**
```bash
ansible-playbook site.yml \
  -e "ngc_api_key=$NGC_API_KEY" \
  -e "ngc_docker_api_key=$NGC_DOCKER_API_KEY" \
  -e "avesha_docker_username=$AVESHA_DOCKER_USERNAME" \
  -e "avesha_docker_password=$AVESHA_DOCKER_PASSWORD" \
  -vvvv
```

### Deployment Verification

1. **Check all namespaces:**
```bash
kubectl get namespaces
```

2. **Verify component status:**
```bash
# Infrastructure Components
kubectl get pods -n gpu-operator
kubectl get pods -n monitoring
kubectl get pods -n keda

# AI/ML Components
kubectl get pods -n nim

# Smart Scaler Components
kubectl get pods -n smart-scaler

# Load Testing Components
kubectl get pods -n nim-load-test
```

3. **Check services and endpoints:**
```bash
kubectl get svc --all-namespaces
kubectl get endpoints --all-namespaces
```

4. **Verify KEDA ScaledObjects:**
```bash
kubectl get scaledobjects -n nim
kubectl describe scaledobject llm-demo-keda -n nim
```

5. **Check metrics and monitoring:**
```bash
# Check if Prometheus is collecting metrics
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Check Grafana dashboards
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

## Secret Management

The installer automatically manages the following secrets:

### NGC Secrets (for NVIDIA components)
- **ngc-secret**: Docker registry secret for pulling NVIDIA images
- **ngc-api-secret**: API key secret for NGC access

### Avesha Secrets (for Smart Scaler components)
- **avesha-systems**: Docker registry secret for pulling Smart Scaler images

### ConfigMaps
- **mesh-config**: Smart Scaler inference configuration
- **locustfile**: Load testing script configuration

## Ansible Roles Overview

### 1. helm_chart_install
**Purpose**: Manages Helm chart installations

**Features**:
- Chart version specification
- Namespace creation and management
- Chart values configuration
- Repository management
- Installation validation

**Usage**: Handles GPU Operator, Prometheus Stack, KEDA, and NIM Operator

### 2. manifest_install
**Purpose**: Manages Kubernetes manifest deployments

**Features**:
- Template variable substitution
- Namespace management
- Manifest validation
- Wait conditions for readiness
- Resource dependency handling

**Usage**: Handles all custom manifests (NIM Cache, NIM Service, KEDA ScaledObject, Smart Scaler, Locust)

### 3. command_exec
**Purpose**: Executes shell commands with enhanced features

**Features**:
- Environment variable support
- Error handling and retries
- Conditional execution
- Kubeconfig and context management
- Secret management operations

**Usage**: Handles secret creation, verification, and ConfigMap management

## Execution Process

The installer follows this systematic process:

1. **Initialization Phase**
   - Validates prerequisites and environment
   - Loads configuration from `user_input.yml`
   - Sets up kubeconfig and context
   - Verifies cluster connectivity

2. **Infrastructure Installation Phase**
   - Installs GPU Operator for GPU management
   - Deploys Prometheus stack for monitoring
   - Installs Pushgateway for custom metrics
   - Deploys KEDA for autoscaling capabilities

3. **AI/ML Platform Installation Phase**
   - Installs NIM Operator for AI workload management
   - Creates necessary secrets for registry access
   - Deploys NIM Cache for model preparation
   - Deploys NIM Service for inference endpoints

4. **Smart Scaler Integration Phase**
   - Configures KEDA ScaledObject for intelligent scaling
   - Creates configuration for Smart Scaler inference
   - Deploys Smart Scaler inference optimization component

5. **Load Testing Setup Phase**
   - Creates Locust configuration
   - Deploys load testing framework

6. **Verification Phase**
   - Checks all components are installed and running
   - Validates component health and readiness
   - Ensures proper inter-component communication
   - Verifies metrics collection and scaling configuration

## Troubleshooting

### Common Issues

1. **NGC Secret Creation Fails**
```bash
# Check NGC environment variables
echo $NGC_API_KEY
echo $NGC_DOCKER_API_KEY

# Verify nim namespace exists
kubectl get ns nim

# Check existing secrets
kubectl get secrets -n nim
kubectl describe secret ngc-secret -n nim
kubectl describe secret ngc-api-secret -n nim
```

2. **NIM Service Not Starting**
```bash
# Check NIM service pods
kubectl get pods -n nim -l app=meta-llama3-8b-instruct

# Check pod logs
kubectl logs -n nim -l app=meta-llama3-8b-instruct

# Check events
kubectl get events -n nim --sort-by=.metadata.creationTimestamp

# Verify GPU resources
kubectl describe nodes | grep nvidia.com/gpu
```

3. **KEDA ScaledObject Issues**
```bash
# Check ScaledObject status
kubectl get scaledobjects -n nim
kubectl describe scaledobject llm-demo-keda -n nim

# Check KEDA operator logs
kubectl logs -n keda -l app=keda-operator

# Verify Prometheus connectivity
kubectl exec -it -n nim deployment/meta-llama3-8b-instruct -- curl -s "http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up"
```

4. **Smart Scaler Inference Issues**
```bash
# Check Smart Scaler pods
kubectl get pods -n smart-scaler

# Check logs
kubectl logs -n smart-scaler -l service=inference-tenant-app

# Verify ConfigMap
kubectl get configmap mesh-config -n smart-scaler -o yaml

# Check resource availability
kubectl describe pod -n smart-scaler -l service=inference-tenant-app
```

5. **Load Testing Issues**
```bash
# Check Locust deployment
kubectl get pods -n nim-load-test

# Check Locust logs
kubectl logs -n nim-load-test -l app=locust-load

# Verify target connectivity
kubectl exec -it -n nim-load-test deployment/locust-load -- curl -s http://meta-llama3-8b-instruct.nim.svc.cluster.local:8000/v1/models
```

6. **Metrics Collection Issues**
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Then visit http://localhost:9090/targets

# Check ServiceMonitor for NIM service
kubectl get servicemonitor -n nim

# Verify Pushgateway
kubectl get pods -n monitoring -l app=pushgateway
kubectl logs -n monitoring -l app=pushgateway
```

### Log Analysis

1. **Application logs:**
```bash
# Get logs from specific pods
kubectl logs -n <namespace> <pod-name>

# Follow logs in real-time
kubectl logs -n <namespace> <pod-name> -f

# Get previous container logs
kubectl logs -n <namespace> <pod-name> --previous

# Multi-container pod logs
kubectl logs -n <namespace> <pod-name> -c <container-name>
```

2. **Ansible execution logs:**
```bash
# Run with verbose output for debugging
ansible-playbook site.yml -vvvv

# Check specific task output
ansible-playbook site.yml --step

# Skip specific tasks
ansible-playbook site.yml --skip-tags="gpu_operator,monitoring"
```

### Performance Monitoring

1. **GPU Utilization:**
```bash
# Check GPU metrics in Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Query: DCGM_FI_DEV_GPU_UTIL

# Direct GPU monitoring on nodes
kubectl exec -it -n gpu-operator -l app=nvidia-device-plugin-daemonset -- nvidia-smi
```

2. **NIM Service Performance:**
```bash
# Check inference latency and throughput
kubectl port-forward -n nim svc/meta-llama3-8b-instruct 8000:8000
curl -X POST http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "meta-llama3-8b-instruct", "prompt": "Hello", "max_tokens": 10}'
```

3. **Scaling Metrics:**
```bash
# Monitor KEDA scaling decisions
kubectl logs -n keda -l app=keda-operator -f

# Check HPA status
kubectl get hpa -n nim

# Monitor Smart Scaler scaling metrics
kubectl port-forward -n monitoring svc/pushgateway 9091:9091
curl http://localhost:9091/metrics | grep smartscaler_hpa_num_pods
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-component`)
3. Make your changes following the existing patterns
4. Test your changes in a development environment
5. Commit your changes (`git commit -am 'Add new component support'`)
6. Push to the branch (`git push origin feature/new-component`)
7. Create a Pull Request with detailed description

### Development Guidelines

- Follow existing Ansible role patterns
- Add appropriate documentation for new components
- Include validation tasks for new features
- Test changes in isolated environments
- Update user_input.yml examples for new configurations
- Ensure proper resource limits and requests
- Add monitoring and metrics for new components
- Follow security best practices for secrets and access

