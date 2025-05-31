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
5. Python 3.x and pip installed

## Required Environment Variables

The following environment variables are required:

```bash
# NGC API Credentials
export NGC_API_KEY="your-ngc-api-key"
export NGC_DOCKER_API_KEY="your-ngc-docker-api-key"
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

### 5. NIM (NVIDIA Instance Manager)
- Namespace: `nim`
- Chart: `nvidia-instance-manager`
- Purpose: GPU instance management

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
```

## Installation

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

5. Run the installation:
```bash
# Basic execution
ansible-playbook site.yml

# With NGC credentials from environment variables
ansible-playbook site.yml -e "ngc_api_key=$NGC_API_KEY" -e "ngc_docker_api_key=$NGC_DOCKER_API_KEY"

# With verbose output for debugging
ansible-playbook site.yml -e "ngc_api_key=$NGC_API_KEY" -e "ngc_docker_api_key=$NGC_DOCKER_API_KEY" -vvvv
```

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

## License

[Add your license information here]
