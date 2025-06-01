# Smart Scaler Apps Installer

Ansible-based installer for Smart Scaler components and dependencies.

## Project Structure

```
smartscaler-apps-installer/
├── ansible.cfg                 # Ansible configuration
├── inventory/
│   └── hosts                  # Inventory file
├── group_vars/
│   └── all/
│       ├── main.yml          # Common variables
│       └── vault.yml         # Encrypted sensitive data
├── roles/
│   ├── helm_chart_install/   # Helm chart installation role
│   ├── manifest_install/     # Kubernetes manifest installation role
│   └── command_exec/         # Shell command execution role
├── files/
│   ├── kubeconfig           # Kubernetes configuration
│   └── pushgateway.yaml     # Pushgateway manifest
├── requirements.txt          # Python package dependencies
├── requirements.yml          # Ansible Galaxy collections
└── tasks/
    ├── process_execution_item.yml    # Task execution handler
    └── process_execution_order.yml   # Main execution orchestrator
```

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

## Required Environment Variables

The following environment variables are required:

```bash
# NGC API Credentials
export NGC_API_KEY="your-ngc-api-key"
export NGC_DOCKER_API_KEY="your-ngc-docker-api-key"

# Avesha Systems Docker Registry Credentials
export AVESHA_DOCKER_USERNAME="your-avesha-username"
export AVESHA_DOCKER_PASSWORD="your-avesha-password"
```

## Components

### 1. GPU Operator
- Namespace: `gpu-operator`
- Chart: `gpu-operator`
- Version: `v25.3.0`
- Purpose: NVIDIA GPU management

### 2. Prometheus Stack
- Namespace: `monitoring`
- Chart: `kube-prometheus-stack`
- Version: `55.5.0`
- Components:
  - Prometheus
  - Grafana
  - AlertManager

### 3. Pushgateway
- Namespace: `monitoring`
- Deployment: Custom manifest
- Purpose: Metrics aggregation

### 4. KEDA
- Namespace: `keda`
- Chart: `keda`
- Purpose: Kubernetes Event-driven Autoscaling

### 5. NIM (NVIDIA NIM Operator)
- Namespace: `nim`
- Chart: `k8s-nim-operator`
- Purpose: GPU instance management

### 6. NIM Cache
- Namespace: `nim`
- Type: Custom manifest
- Purpose: Download and prep LLM models with NIM Cache
- Features:
  - Parameterized configuration
  - GPU-aware scheduling
  - NGC integration
  - Persistent volume management

## Roles

### 1. helm_chart_install
Handles the installation and configuration of Helm charts.
- Supports chart version specification
- Handles namespace creation
- Manages chart values
- Supports chart repository management

### 2. manifest_install
Manages Kubernetes manifest deployments.
- Supports template variables
- Handles namespace management
- Validates manifests before application
- Supports wait conditions

### 3. command_exec
Executes shell commands with enhanced features.
- Environment variable support
- Error handling and retries
- Conditional execution
- Kubeconfig and context management

## Configuration

### User Input Configuration
The `user_input.yml` file contains all configurable parameters:

```yaml
# Component selection and order
execution_order:
  - gpu_operator_chart
  - prometheus_stack
  - pushgateway_manifest
  - keda_chart
  - nim_operator_chart
  - create_ngc_secrets
  - verify_ngc_secrets

# Component configurations
helm_charts:
  gpu_operator_chart:
    ...
  prometheus_stack:
    ...
  keda_chart:
    ...
  nim_operator_chart:
    ...

manifests:
  pushgateway_manifest:
    ...

command_exec:
  - name: "create_ngc_secrets"
    ...
  - name: "verify_ngc_secrets"
    ...

kubernetes_deployment:
  control_plane_nodes:
    - ansible_host: "YOUR_MASTER_NODE_IP"  # Update this IP
      node_name: "master-1"
  worker_nodes:
    - ansible_host: "YOUR_WORKER_NODE_IP"  # Update this IP
      node_name: "worker-1"

```

### NIM Cache Configuration
The NIM Cache manifest (`files/nim-cache.yaml.j2`) is highly parameterized and can be customized through `user_input.yml`:

```yaml
nim_cache_manifest:
  name: nim-cache-setup
  manifest_file: "files/nim-cache.yaml.j2"
  namespace: nim
  variables:
    # Basic Configuration
    nim_cache_name: "meta-llama3-8b-instruct"
    nim_cache_namespace: "nim"
    
    # Runtime Configuration
    nim_cache_runtime_class: "nvidia"
    nim_cache_tolerations:
      - key: "nvidia.com/gpu"
        operator: "Exists"
        effect: "NoSchedule"
    
    # Model Configuration
    nim_cache_model_puller: "nvcr.io/nim/meta/llama-3.1-8b-instruct:1.8.4"
    nim_cache_model_engine: "vllm"
    nim_cache_tensor_parallelism: "1"
    nim_cache_qos_profile: "throughput"
    
    # Storage Configuration
    nim_cache_pvc_create: true
    nim_cache_storage_class: "local-path"
    nim_cache_pvc_size: "200Gi"
    nim_cache_volume_access_mode: "ReadWriteOnce"
```

#### Customization Options:
1. **Basic Settings**
   - `nim_cache_name`: Name of the NIM Cache resource
   - `nim_cache_namespace`: Target namespace

2. **Runtime Settings**
   - `nim_cache_runtime_class`: Kubernetes runtime class
   - `nim_cache_tolerations`: Node tolerations for GPU scheduling

3. **Model Settings**
   - `nim_cache_model_puller`: NGC model image
   - `nim_cache_model_engine`: Model engine (e.g., vllm)
   - `nim_cache_tensor_parallelism`: Tensor parallelism degree
   - `nim_cache_qos_profile`: Quality of service profile

4. **Storage Settings**
   - `nim_cache_pvc_create`: Whether to create a new PVC
   - `nim_cache_storage_class`: Storage class for PVC
   - `nim_cache_pvc_size`: PVC size
   - `nim_cache_volume_access_mode`: Volume access mode

## (Optional) Kubernetes Installation

⚠️ **IMPORTANT**: The **ONLY** supported method for installing Kubernetes is through the `setup_kubernetes.sh` script. This script handles all necessary setup steps and validations.

### Prerequisites

Before starting the installation:

1. **Ensure all nodes meet the system requirements:**
   - Ubuntu-based system
   - SSH access configured
   - Sufficient resources (CPU, RAM, Storage)
   - Network connectivity between nodes

2. **Setup Python Environment**
   ```bash
   # Create and activate virtual environment
   python3 -m venv venv
   source venv/bin/activate

   # Install dependencies
   pip install -r requirements.txt
   
   # Install Ansible collections
   ansible-galaxy install -r requirements.yml
   ```

3. **SSH Key Setup**
   ```bash
   # Generate SSH key
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/k8s_rsa -N ""

   # Copy SSH key to each node (repeat for each node)
   ssh-copy-id -i ~/.ssh/k8s_rsa.pub user@node-ip

### Kubernetes Installation

1. Update node IPs in `user_input.yml`:
   ```yaml
   kubernetes_deployment:
     enabled: true  # Must be set to true
     control_plane_nodes:
       - ansible_host: "YOUR_MASTER_NODE_IP"  # Update this IP
         name: "master-1"
     worker_nodes:
       - ansible_host: "YOUR_WORKER_NODE_IP"  # Update this IP
         name: "worker-1"
   ```

2. **Run the Kubernetes setup script:**
   ```bash
   chmod +x setup_kubernetes.sh
   ./setup_kubernetes.sh
   ```
   
   The script will:
   - create an inventory.ini file for kubespray
   - Validate your configuration
   - Test SSH connectivity to all nodes
   - Generate necessary inventory files
   - Deploy Kubernetes components
   - Verify the installation

4. Verify the installation:
   ```bash
   kubectl get nodes -o wide
   kubectl cluster-info
   ```

### Component Installation

After Kubernetes is successfully installed:

1. Clone the repository:
```bash
git clone https://github.com/smart-scaler/smartscaler-apps-installer.git
cd smartscaler-apps-installer
```

2. Set up Python virtual environment (recommended):
```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

3. Set required environment variables:
```bash
export NGC_API_KEY="your-ngc-api-key"
export NGC_DOCKER_API_KEY="your-ngc-docker-api-key"
```

4. Place your kubeconfig file:
```bash
cp /path/to/your/kubeconfig files/kubeconfig
```

5. Update node IPs in `user_input.yml`:
```yaml
kubernetes_deployment:
  control_plane_nodes:
    - ansible_host: "YOUR_MASTER_NODE_IP"  # Update this IP
      node_name: "master-1"
  worker_nodes:
    - ansible_host: "YOUR_WORKER_NODE_IP"  # Update this IP
      node_name: "worker-1"
```

6. Run the Kubernetes setup script:
```bash
chmod +x setup_kubernetes.sh
./setup_kubernetes.sh
```

7. Update kubeconfig settings in user_input.yml:
```yaml
# Kubeconfig settings
global_kubeconfig: "files/kubeconfig"
global_kubecontext: "your-cluster-context"
```

8. Run the installation:
```bash
# Basic execution
ansible-playbook site.yml

# With NGC credentials from environment variables
ansible-playbook site.yml \
  -e "ngc_api_key=$NGC_API_KEY" \
  -e "ngc_docker_api_key=$NGC_DOCKER_API_KEY" \
  -e "avesha_docker_username=$AVESHA_DOCKER_USERNAME" \
  -e "avesha_docker_password=$AVESHA_DOCKER_PASSWORD"

# With verbose output for debugging
ansible-playbook site.yml \
  -e "ngc_api_key=$NGC_API_KEY" \
  -e "ngc_docker_api_key=$NGC_DOCKER_API_KEY" \
  -e "avesha_docker_username=$AVESHA_DOCKER_USERNAME" \
  -e "avesha_docker_password=$AVESHA_DOCKER_PASSWORD" \
  -vvvv
```

### Important Notes

1. **IP Configuration**
   - Always update the node IPs in `user_input.yml` before running `setup_kubernetes.sh`
   - Ensure the IPs are reachable and have proper SSH access
   - Verify network connectivity between nodes

2. **Setup Script**
   - `setup_kubernetes.sh` must be run after updating IPs
   - The script requires proper permissions (`chmod +x setup_kubernetes.sh`)
   - Monitor the script output for any errors
   - Wait for the script to complete before proceeding with other configurations

## Execution Process

The installer follows this process:

1. **Initialization**
   - Validates prerequisites
   - Loads configuration from `user_input.yml`
   - Sets up environment variables

2. **Component Installation**
   - Follows the order specified in `execution_order`
   - For each component:
     - Determines component type (helm/manifest/command)
     - Executes appropriate role
     - Validates successful installation

3. **NGC Secret Management**
   - Creates/updates NGC secrets in the `nim` namespace
   - Verifies secret creation
   - Handles secret rotation if needed

4. **Verification**
   - Checks all components are installed
   - Validates component health
   - Ensures proper configuration

## Troubleshooting

### Common Issues

1. NGC Secret Creation Fails
```bash
# Check NGC environment variables
echo $NGC_API_KEY
echo $NGC_DOCKER_API_KEY

# Verify nim namespace exists
kubectl get ns nim

# Check existing secrets
kubectl get secrets -n nim
```

2. Helm Chart Installation Fails
```bash
# Check Helm repositories
helm repo list

# Update Helm repositories
helm repo update

# Verify chart version availability
helm search repo <chart-name> --versions
```

3. Manifest Application Fails
```bash
# Check manifest syntax
kubectl apply --dry-run=client -f files/pushgateway.yaml

# Verify namespace exists
kubectl get ns <namespace>

# Check for existing resources
kubectl get all -n <namespace>
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Documentation

Detailed documentation is available for various components and configurations:

### Core Configuration
- [User Input Configuration Guide](docs/USER_INPUT_CONFIGURATION.md)
- [Kubernetes Configuration](docs/KUBERNETES_CONFIGURATION.md)

### Feature-specific Documentation
- [NVIDIA Container Runtime Configuration](docs/NVIDIA_CONTAINER_RUNTIME.md)
- [Kubernetes Firewall Configuration](docs/KUBERNETES_FIREWALL.md)

### Quick Links
- [Installation Guide](#installation)
- [Components Overview](#components)
- [Troubleshooting Guide](#troubleshooting)
- [Contributing Guidelines](#contributing)

