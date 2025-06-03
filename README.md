# Smart Scaler Apps Installer

Ansible-based installer for Smart Scaler components and dependencies.

## Important Prerequisites for Apps Installation

Before proceeding with the Smart Scaler applications deployment, ensure:

1. **Cluster Accessibility**
   - The Kubernetes cluster endpoint must be accessible from the machine where you're running this installer
   - Verify connectivity by running `kubectl get nodes` using your kubeconfig file

2. **Configuration Requirements**
   - The `kubernetes_deployment.enabled` flag in `user_input.yml` must be set to `false` before running apps installation
   - This prevents unintended cluster setup operations during app deployment

3. **Sudo Access Requirements**
   - Some installation steps require sudo privileges for:
     - Installing system-wide Python packages
     - Configuring firewall rules
     - Setting up NVIDIA runtime (if enabled)
   - You can provide sudo access in one of these ways:
     - Set password in `user_input.yml`: `kubernetes_deployment.ansible_sudo_pass`
     - Set environment variable: `export ANSIBLE_SUDO_PASS="your_password"`
     - Use the `-K` flag when running playbooks to be prompted for the password

   > **Note**: If you're using a virtual environment, some Python packages still need to be installed system-wide for proper functionality with Ansible and Kubernetes tools.

## Ansible Project Structure

```sh
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

2. **Environment Prerequisite**

- Python 3.x and pip installed
- Git installed
- SSH key generation capability
- helm v3.15.0
- kubectl v1.25.0


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
# Option 1: Install with sudo (recommended for system-wide tools)
chmod +x files/install_requirements.sh
sudo ./files/install_requirements.sh

# The requirements include:
# - ansible>=2.10
# - openshift
# - kubernetes
# - PyYAML
# - kubernetes-validate>=1.28.0
```

4. **Install Ansible collections:**

```bash
# Install required collections with locale settings
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 ansible-galaxy collection install -r requirements.yml --force

# Verify the installation
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 ansible-galaxy collection list | grep -E "community.general|kubernetes.core"
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

⚠️ **IMPORTANT**: The **ONLY** supported method for installing Kubernetes is through the `setup_kubernetes.sh` script with sudo privileges.

### Configuration

1. **Update node IPs in `user_input.yml`:**

Update the following locations in `user_input.yml`:
```yaml
# API Server
api_server:
  host: "YOUR_PUBLIC_IP"

# Control Plane Node
control_plane_nodes:
  - ansible_host: "YOUR_PUBLIC_IP"
    private_ip: "YOUR_PRIVATE_IP"
```yaml

2. **KUBERNETES CLUSTER DEPLOYMENT CONFIGURATION:**

# =============================================================================
# KUBERNETES CLUSTER DEPLOYMENT CONFIGURATION
# =============================================================================
# This section controls the setup and configuration of the Kubernetes cluster
# using Kubespray. Set 'enabled: true' to deploy a new cluster, 'false' to skip.
# =============================================================================

kubernetes_deployment:
  enabled: false                                # Set to 'true' to deploy K8s cluster, 'false' to skip

  # =============================================================================
  # API SERVER CONFIGURATION
  # =============================================================================
  # Configure the Kubernetes API server endpoint that will be used for cluster
  # management and kubectl/helm operations. This should be the public IP address
  # or DNS name where the API server will be accessible.
  # =============================================================================
  api_server:
    host: "<YOUR_API_SERVER_IP>"                # REQUIRED: Replace with your master node's public IP
    port: 6443                                  # API server port (default: 6443, change if needed)
    secure: true                                # Use HTTPS for secure API server connection

  # =============================================================================
  # FIREWALL CONFIGURATION
  # =============================================================================
  # Configure firewall rules for the Kubernetes cluster. The installer will
  # automatically open required ports for K8s components (6443, 2379-2380, etc.)
  # Use 'allow_additional_ports' to open additional custom ports if needed.
  # =============================================================================
  firewall:
    enabled: true                               # Enable automatic firewall configuration
    allow_additional_ports: []                  # Additional ports to open (e.g., ["8080", "9090", "3000"])

  # =============================================================================
  # NVIDIA GPU RUNTIME CONFIGURATION
  # =============================================================================
  # Configure NVIDIA GPU support for containerized workloads. This is required
  # for AI/ML workloads that need GPU acceleration. The installer will set up
  # the NVIDIA Container Toolkit and configure containerd runtime.
  # =============================================================================
  nvidia_runtime:
    enabled: true                               # Enable NVIDIA GPU runtime support
    install_toolkit: true                       # Install NVIDIA Container Toolkit automatically
    configure_containerd: true                  # Configure containerd with NVIDIA runtime
    create_runtime_class: true                  # Create Kubernetes RuntimeClass for GPU workloads

  # =============================================================================
  # SSH ACCESS CONFIGURATION
  # =============================================================================
  # Configure SSH access for cluster node management. Kubespray uses SSH to
  # connect to nodes and perform installation tasks. Generate SSH keys using:
  # ssh-keygen -t rsa -b 4096 -f ~/.ssh/k8s_rsa -N ""
  # =============================================================================
  ssh_key_path: "<PATH_TO_YOUR_SSH_PRIVATE_KEY>"    # REQUIRED: Full path to SSH private key
                                                    # Example: "/home/username/.ssh/k8s_rsa"
  default_ansible_user: "<SSH_USERNAME>"            # REQUIRED: SSH username for node access
                                                    # Common values: "ubuntu", "root", "centos"

  # =============================================================================
  # CONTROL PLANE NODES CONFIGURATION
  # =============================================================================
  # Define the master nodes that will run the Kubernetes control plane components.
  # For production, use 3 master nodes for high availability. For development,
  # a single master node is sufficient.
  # =============================================================================
  control_plane_nodes:
    - name: "<NODE_HOSTNAME>"                   # REQUIRED: Unique hostname/identifier
                                                # Example: "k8s-master-1", "control-plane-01"
      ansible_host: "<PUBLIC_IP_ADDRESS>"       # REQUIRED: Public IP address of the master node
                                                # Example: "203.0.113.10"
      ansible_user: "<SSH_USERNAME>"            # REQUIRED: SSH user for this specific node
                                                # Should match or override default_ansible_user
      ansible_become: true                      # Enable privilege escalation (sudo)
      ansible_become_method: sudo               # Method for privilege escalation
      private_ip: "<PRIVATE_IP_ADDRESS>"        # REQUIRED: Private/internal IP address
                                                # Example: "10.0.1.10" (AWS), "192.168.1.10" (local)

    # OPTIONAL: Add additional master nodes for high availability
    # - name: "<NODE_HOSTNAME_2>"
    #   ansible_host: "<PUBLIC_IP_ADDRESS_2>"
    #   ansible_user: "<SSH_USERNAME>"
    #   ansible_become: true
    #   ansible_become_method: sudo
    #   private_ip: "<PRIVATE_IP_ADDRESS_2>"

  # =============================================================================
  # KUBERNETES COMPONENTS CONFIGURATION
  # =============================================================================
  # Configure the core Kubernetes components and networking. These settings
  # determine how your cluster will handle networking, DNS, and container runtime.
  # =============================================================================
  network_plugin: calico                        # Container Network Interface (CNI) plugin
                                                # Options: calico, flannel, weave, cilium
  container_runtime: containerd                 # Container runtime for pods
                                                # Options: containerd, docker (deprecated)
  dns_mode: coredns                            # DNS service for cluster
                                                # Options: coredns, kubedns

  # =============================================================================
  # NETWORK CONFIGURATION
  # =============================================================================
  # Define the IP address ranges for Kubernetes services and pods. Ensure these
  # ranges don't conflict with your existing network infrastructure.
  # =============================================================================
  network_config:
    service_subnet: "10.233.0.0/18"            # CIDR for Kubernetes services
                                                # Default range, change if conflicts exist
    pod_subnet: "10.233.64.0/18"               # CIDR for pod network
                                                # Default range, change if conflicts exist  
    node_prefix: 24                             # Subnet size for each node
                                                # Default: 24 (256 IPs per node)

# =============================================================================
# CONFIGURATION EXAMPLES
# =============================================================================
# 
# Example 1: Single Master Node (Development)
# -------------------------------------------
# control_plane_nodes:
#   - name: "k8s-master"
#     ansible_host: "203.0.113.10"
#     ansible_user: "ubuntu"
#     ansible_become: true
#     ansible_become_method: sudo
#     private_ip: "10.0.1.10"
#
# Example 2: High Availability Setup (Production)
# -----------------------------------------------
# control_plane_nodes:
#   - name: "k8s-master-1"
#     ansible_host: "203.0.113.10"
#     ansible_user: "ubuntu"
#     ansible_become: true
#     ansible_become_method: sudo
#     private_ip: "10.0.1.10"
#   - name: "k8s-master-2"
#     ansible_host: "203.0.113.11"
#     ansible_user: "ubuntu"
#     ansible_become: true
#     ansible_become_method: sudo
#     private_ip: "10.0.1.11"
#   - name: "k8s-master-3"
#     ansible_host: "203.0.113.12"
#     ansible_user: "ubuntu"
#     ansible_become: true
#     ansible_become_method: sudo
#     private_ip: "10.0.1.12"
#
# =============================================================================
```

**Important Notes about API Server Configuration:**

- **`api_server.host`**: This must be set to the **public IP address** or **domain name** that will be used to access the Kubernetes API server
- This IP will be:
  - Used in the kubeconfig file as the server endpoint
  - Added to the API server's SSL certificate as a Subject Alternative Name (SAN)
  - The endpoint that kubectl and other clients will use to connect to the cluster
- **Do NOT use placeholder values** like `<API SERVER IP ADDRESS>` - this will cause deployment failures
- For cloud deployments (AWS, GCP, Azure), use the **public IP** of your master node
- For on-premises deployments, use the **externally accessible IP** of your master node

**Example configurations:**

```yaml
# For AWS EC2 instance
api_server:
  host: "3.239.19.44"  # AWS public IP
  
# For on-premises with static IP
api_server:
  host: "192.168.1.100"  # Your public/accessible IP

# For domain-based access
api_server:
  host: "k8s-master.yourdomain.com"  # Your domain name
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

⚠️ **IMPORTANT**: The **ONLY** supported method for installing Kubernetes is through the `setup_kubernetes.sh` script with sudo privileges.

```bash
# Make the script executable
chmod +x setup_kubernetes.sh

# Run the installation script with sudo
sudo ./setup_kubernetes.sh
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

> **Note**: The script requires sudo privileges for:
> - Installing system packages
> - Configuring firewall rules
> - Setting up container runtime
> - Configuring network interfaces
> - Installing NVIDIA drivers (if enabled)

### Post-Installation Verification

After the script completes, verify the installation:

```bash
# Check node status
kubectl get nodes -o wide

# View cluster info
kubectl cluster-info

# Check all pods
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
# Global Control Plane IP
global_control_plane_ip: "YOUR_PUBLIC_IP"
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

## Prerequisites

Before proceeding with the applications deployment:

1. **Cluster Accessibility**
   - Ensure the Kubernetes cluster endpoint is accessible from the machine running this installer
   - Verify connectivity by running: `KUBECONFIG=files/kubeconfig kubectl get nodes`
   - If you cannot access the cluster, check network connectivity and firewall rules

2. **Configuration Requirements**
   - Set `kubernetes_deployment.enabled: false` in your `user_input.yml`
   - This is crucial to prevent unintended cluster setup operations during app deployment
   - Example configuration:

     ```yaml
     kubernetes_deployment:
       enabled: false  # Must be false for apps deployment

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
# Install required collections with locale settings
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 ansible-galaxy collection install -r requirements.yml --force

# Verify the installation
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 ansible-galaxy collection list | grep -E "community.general|kubernetes.core"
```

### Deployment Process

1. **Deployment with explicit credentials:**

```bash
sudo ansible-playbook site.yml \
  -e "ngc_api_key=$NGC_API_KEY" \
  -e "ngc_docker_api_key=$NGC_DOCKER_API_KEY" \
  -e "avesha_docker_username=$AVESHA_DOCKER_USERNAME" \
  -e "avesha_docker_password=$AVESHA_DOCKER_PASSWORD"
```

2. **Debug deployment with verbose output:**

```bash
sudo ansible-playbook site.yml \
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

Expected output:

```sh
default              Active   5h2m
gpu-operator         Active   93m
keda                 Active   91m
kube-node-lease      Active   5h2m
kube-public          Active   5h2m
kube-system          Active   5h2m
local-path-storage   Active   5h
monitoring           Active   93m
nim                  Active   91m
nim-load-test        Active   89m
pushgateway-system   Active   92m
smart-scaler         Active   90m
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

Expected output:

```sh
## Infrastructure Components
# GPU Operator
gpu-operator-666bbffcd-drrwk                                  1/1     Running   0          96m
gpu-operator-node-feature-discovery-gc-7c7f68d5f4-dz7jk       1/1     Running   0          96m
gpu-operator-node-feature-discovery-master-58588c6967-8pjhc   1/1     Running   0          96m
gpu-operator-node-feature-discovery-worker-xkbk2              1/1     Running   0          96m
# Monitoring
alertmanager-prometheus-kube-prometheus-alertmanager-0   2/2     Running   0          98m
prometheus-grafana-67dc5c9fc9-5jzhh                      3/3     Running   0          98m
prometheus-kube-prometheus-operator-775d58dc6b-bgglg     1/1     Running   0          98m
prometheus-kube-state-metrics-856b96f64d-7st5q           1/1     Running   0          98m
prometheus-prometheus-kube-prometheus-prometheus-0       2/2     Running   0          98m
prometheus-prometheus-node-exporter-nm8zl                1/1     Running   0          98m
pushgateway-65497548cc-6v7sv                             1/1     Running   0          97m
# Keda
keda-admission-webhooks-7c6fc8d849-9cchf          1/1     Running   0             98m
keda-operator-6465596cb9-4j54h                    1/1     Running   1 (98m ago)   98m
keda-operator-metrics-apiserver-dc4dd6d79-gzxpq   1/1     Running   0             98m

# AI/ML
meta-llama3-8b-instruct-pod             0/1     Pending   0          97m
nim-k8s-nim-operator-7565b7477b-6d7rs   1/1     Running   0          98m

# Smart Scaler
smart-scaler-llm-inf-5f4bf754dd-6qbm9   1/1     Running   0          98m

# Load Testing Service
locust-load-54748fd47d-tndsr   1/1     Running   0          97m
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

Expected output:

```sh
llm-demo-keda   meta-llama3-8b-instruct   1     8     prometheus    False   Unknown   Unknown    Unknown   100m
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

1. **Locale Issues with Ansible**

If you encounter locale-related errors like:
```
ERROR: Ansible could not initialize the preferred locale: unsupported locale setting
```

Fix this by running the following commands:
```bash
# Install and configure locales
sudo apt-get update && sudo apt-get install -y locales
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Set locale for current session
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
```

2. **Python bad interpreter**

If you get this error: `smartscaler-apps-installer/venv/bin/python: bad interpreter: No such file or directory`, try to run the following commands:

```sh
deactivate

rm -rf smartscaler-apps-installer/smartscaler-apps-installer/venv/

python3 -m venv venv

source venv/bin/activate

# Run again step 3 from "Setting Up Local Environment" section
pip install -r requirements.txt
```

3. **Failed to find required executable "rsync"**

```sh
# Ubuntu as an example
sudo apt update
sudo apt install rsync
```

4. **NGC Secret Creation Fails**

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

5. **NIM Service Not Starting**

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

6. **KEDA ScaledObject Issues**

```bash
# Check ScaledObject status
kubectl get scaledobjects -n nim
kubectl describe scaledobject llm-demo-keda -n nim

# Check KEDA operator logs
kubectl logs -n keda -l app=keda-operator

# Verify Prometheus connectivity
kubectl exec -it -n nim deployment/meta-llama3-8b-instruct -- curl -s "http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up"
```

7. **Smart Scaler Inference Issues**

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

8. **Load Testing Issues**

```bash
# Check Locust deployment
kubectl get pods -n nim-load-test

# Check Locust logs
kubectl logs -n nim-load-test -l app=locust-load

# Verify target connectivity
kubectl exec -it -n nim-load-test deployment/locust-load -- curl -s http://meta-llama3-8b-instruct.nim.svc.cluster.local:8000/v1/models
```

9. **Metrics Collection Issues**

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

## Running the Playbook

To deploy the Kubernetes cluster, run:

```bash
ansible-playbook kubernetes.yml --ask-become-pass
```
