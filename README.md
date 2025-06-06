# Smart Scaler Apps Installer

Ansible-based installer for Smart Scaler components and Kubernetes cluster deployment.

## Table of Contents

1. [Prerequisites for Deploying K8s Cluster](#1-prerequisites-for-deploying-k8s-cluster)
2. [Installation Steps for Deploying K8s Cluster](#2-installation-steps-for-deploying-k8s-cluster)
3. [Prerequisites for Installing SmartScaler Apps](#3-prerequisites-for-installing-smartscaler-apps)
4. [Instructions to Deploy SmartScaler Apps](#4-instructions-to-deploy-smartscaler-apps)
5. [Documentation Links](#documentation-links)
6. [Troubleshooting](#troubleshooting)

---

## 1. Prerequisites for Deploying K8s Cluster

### System Requirements

#### Control Plane Nodes (Master)

- **CPU**: 8 cores minimum
- **RAM**: 16GB minimum
- **Storage**: 500GB minimum
- **OS**: Ubuntu 22.04+ or compatible Linux distribution

#### Worker Nodes

- **CPU**: 8 cores minimum
- **RAM**: 16GB minimum
- **Storage**: 500GB minimum
- **OS**: Same as control plane nodes

### Required Software

- Python 3.x and pip
- Git
- SSH key generation capability
- helm v3.15.0+
- kubectl v1.25.0+

### Network Requirements

- SSH access between installer machine and all cluster nodes
- Internet connectivity for downloading packages
- Open ports: 6443 (API server), 2379-2380 (etcd), 10250 (kubelet)

---

## 2. Installation Steps for Deploying K8s Cluster

### Step 1: Clone Repository and Setup Environment

```bash
# Clone the repository
git clone https://github.com/smart-scaler/smartscaler-apps-installer.git
cd smartscaler-apps-installer

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies with sudo (required for system-wide tools)
chmod +x files/install-requirements.sh
sudo ./files/install-requirements.sh

# Install Ansible collections
sudo LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 ansible-galaxy collection install -r requirements.yml --force
```

### Step 2: Generate SSH Keys

```bash
# Generate SSH key for cluster access
ssh-keygen -t rsa -b 4096 -f ~/.ssh/k8s_rsa -N ""

# Copy SSH key to each node (repeat for all nodes)
ssh-copy-id -i ~/.ssh/k8s_rsa.pub user@node-ip
```

### Step 3: Configure user_input.yml

Edit `user_input.yml` with your cluster configuration:

This section defines the settings required to enable and configure a Kubernetes cluster deployment using Ansible.

#### 🔧 **Note**: Replace placeholders with actual values before running the playbook.

```yaml
kubernetes_deployment:
  enabled: true  # Enable Kubernetes deployment via Ansible

  api_server:
    host: "PUBLIC_IP"        # Public IP of Kubernetes API server
    port: 6443               # Default secure port
    secure: true             # Use HTTPS (recommended)

  ssh_key_path: "/absolute/path/to/.ssh/k8s_rsa"     # SSH private key path
  default_ansible_user: "REPLACE_SSH_USER"           # SSH user (e.g., ubuntu, ec2-user)
  ansible_sudo_pass: ""                              # Optional: sudo password

  control_plane_nodes:
    - name: "master-1"
      ansible_host: "PUBLIC_IP"       # Public IP for SSH
      ansible_user: "REPLACE_SSH_USER"
      ansible_become: true
      ansible_become_method: "sudo"
      ansible_become_user: "root"
      private_ip: "PRIVATE_IP"        # Internal/private IP

```

#### ⚙️ For Single Node: Quick Configuration Update (Command-Line Shortcut)

You can quickly replace the placeholder values in your `user_input.yml` configuration using the following `sed` command:

#### 🧪 Example:

```bash
sed -i \
  -e 's|PUBLIC_IP|203.0.113.10|g' \
  -e 's|PRIVATE_IP|192.168.1.10|g' \
  -e 's|REPLACE_SSH_USER|ubuntu|g' \
  -e 's|/absolute/path/to/.ssh/k8s_rsa|/home/ubuntu/.ssh/id_rsa|g' \
  -e '/kubernetes_deployment:/,/^[^ ]/ s/enabled: false/enabled: true/' \
  path/to/your/user_input.yml
```

> ✅ Use this before running the installer to ensure the configuration is correctly set for a single-node Kubernetes deployment.


### Step 4: Deploy Kubernetes Cluster

```bash
# Make the script executable
chmod +x setup_kubernetes.sh

# Run the installation script with sudo
sudo ./setup_kubernetes.sh
```

### Step 5 Change ownership of the kubeconfig file

```bash
sudo chown $(whoami):$(whoami) files/kubeconfig

# Set the KUBECONFIG environment variable
export KUBECONFIG=output/kubeconfig

# Verify cluster access and node status
kubectl get nodes
```

### Step 6: Verify Installation

```bash
# Check cluster status
kubectl get nodes
kubectl cluster-info

# Verify all system pods are running
kubectl get pods --all-namespaces
```

---

## 3. Prerequisites for Installing SmartScaler Apps

### Cluster Requirements

- **Kubernetes cluster must be running and accessible**
- **kubectl configured with proper kubeconfig**
- **Helm v3.15.0+ installed**

### Required Environment Variables

Set the following environment variables before deployment:

```bash
export NGC_API_KEY="your_ngc_api_key"
export NGC_DOCKER_API_KEY="your_ngc_docker_api_key"
export AVESHA_DOCKER_USERNAME="your_avesha_username"
export AVESHA_DOCKER_PASSWORD="your_avesha_password"
```

### Configure user_input.yml

**Important**: Set `kubernetes_deployment.enabled` to `false` in `user_input.yml` before running apps installation:

```yaml
kubernetes_deployment:
  enabled: false  # Must be false for apps-only deployment

> ℹ️ **Required Kubeconfig Settings** – Already included above; this section can be skipped.

global_control_plane_ip: "YOUR_MASTER_PUBLIC_IP"         # Provide the public IP for metallb/Nginx
global_kubeconfig: "output/kubeconfig"                    # Required: Path to kubeconfig file
global_kubecontext: "kubernetes-admin@cluster.local"     # Required: Kubernetes context
use_global_context: true                                 # Required: Use global context
```
#### Quick Configuration Update (Command-Line Shortcut)

You can quickly replace the placeholder values in your `user_input.yml` configuration using the following `sed` command:

#### 🧪 Example:

```bash
sed -i \
   -e '/kubernetes_deployment:/,/^[^ ]/ s/enabled: true/enabled: false/' \
  path/to/your/user_input.yml
```

### Required Files

Ensure these files exist in the `files/` directory:

- `kubeconfig` - Kubernetes cluster configuration
- `config-inference.json` - Smart Scaler inference configuration
- `locust.py` - Load testing script

---

## 4. Instructions to Deploy SmartScaler Apps

### Step 1: Verify Prerequisites

```bash
# Verify cluster access
kubectl get nodes
kubectl cluster-info

# Verify required tools
kubectl version --client
helm version

# Verify environment variables
echo $NGC_API_KEY
echo $NGC_DOCKER_API_KEY
echo $AVESHA_DOCKER_USERNAME
echo $AVESHA_DOCKER_PASSWORD
```

### Step 2: Deploy Applications

```bash
# Deploy with explicit credentials
sudo ansible-playbook site.yml \
  -e "ngc_api_key=$NGC_API_KEY" \
  -e "ngc_docker_api_key=$NGC_DOCKER_API_KEY" \
  -e "avesha_docker_username=$AVESHA_DOCKER_USERNAME" \
  -e "avesha_docker_password=$AVESHA_DOCKER_PASSWORD" \
  -vvvv
```

### Step 3: Verify Deployment

```bash
# Check all namespaces
kubectl get namespaces

# Expected namespaces:
# - gpu-operator
# - keda
# - monitoring
# - nim
# - nim-load-test
# - smart-scaler


# Verify component status
kubectl get pods -n gpu-operator
kubectl get pods -n monitoring
kubectl get pods -n keda
kubectl get pods -n nim
kubectl get pods -n smart-scaler
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
meta-llama3-8b-instruct-pod             1/1     Running   0          97m
nim-k8s-nim-operator-7565b7477b-6d7rs   1/1     Running   0          98m

# Smart Scaler
smart-scaler-llm-inf-5f4bf754dd-6qbm9   1/1     Running   0          98m

# Load Testing Service
locust-load-54748fd47d-tndsr   1/1     Running   0          97m
```

3. **Check services and endpoints:**

```bash
# Port forward to access services (examples)
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
kubectl port-forward -n nim svc/meta-llama3-8b-instruct 8000:8000
```

---

## Documentation Links

- **[User Input Configuration Guide](docs/USER_INPUT_CONFIGURATION.md)** - Complete user_input.yml guide
- **[User Input Reference](docs/USER_INPUT_REFERENCE.md)** - All configuration options
- **[Kubernetes Configuration](docs/KUBERNETES_CONFIGURATION.md)** - Cluster setup details
- **[Kubernetes Firewall Configuration](docs/KUBERNETES_FIREWALL.md)** - Network and firewall setup
- **[NVIDIA Container Runtime Configuration](docs/NVIDIA_CONTAINER_RUNTIME.md)** - GPU runtime setup

---

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   - Verify SSH keys are properly copied to all nodes
   - Check SSH user permissions and sudo access

2. **Cluster Deployment Failed**
   - Check system requirements are met
   - Verify network connectivity between nodes
   - Review firewall settings

3. **Apps Deployment Failed**
   - Ensure `kubernetes_deployment.enabled` is set to `false`
   - Verify all environment variables are set
   - Check cluster accessibility with `kubectl get nodes`

4. **GPU Support Issues**
   - Verify NVIDIA drivers are installed on nodes
   - Check `nvidia_runtime.enabled` is set to `true`
   - Review GPU operator pod status

### Debug Commands

```bash

# Check specific namespace issues
kubectl describe pods -n <namespace>
kubectl logs -n <namespace> <pod-name>

# Verify cluster resources
kubectl top nodes
kubectl get events --all-namespaces
```

For additional support, please refer to the detailed documentation in the `docs/` folder or create an issue in the repository.

---

## Execution Order Control

The deployment process follows a specific execution order defined in `user_input.yml`. You can control which components to execute by modifying the execution order or using `--extra-vars` with Ansible.

### Available Components

#### Core Infrastructure (Optional)
- `metallb_chart` - MetalLB load balancer installation
- `metallb_l2_config` - L2 configuration for MetalLB
- `metallb_ip_pool` - IP pool configuration for MetalLB
- `nginx_ingress_config` - NGINX ingress controller configuration
- `nginx_ingress_chart` - NGINX ingress controller installation

#### Base Components
- `gpu_operator_chart` - NVIDIA GPU operator installation
- `prometheus_stack` - Prometheus monitoring stack
- `pushgateway_manifest` - Prometheus Pushgateway
- `keda_chart` - KEDA autoscaling
- `nim_operator_chart` - NIM operator installation
- `create_ngc_secrets` - NGC credentials setup
- `verify_ngc_secrets` - NGC credentials verification
- `create_avesha_secret` - Avesha credentials setup

#### NIM 70B Components
- `nim_cache_manifest_70b` - NIM cache for 70B model
- `wait_for_nim_cache_70b` - Wait for cache initialization
- `nim_cache_wait_job_70b` - Cache wait job
- `nim_service_manifest_70b` - NIM service for 70B model
- `keda_scaled_object_manifest_70b` - KEDA scaling configuration
- `create_inference_pod_configmap_70b` - Inference configuration
- `smart_scaler_inference_70b` - Smart Scaler setup
- `create_locust_configmap_70b` - Load test configuration
- `locust_manifest_70b` - Load testing setup
- `smart_scaler_mcp_server_manifest` - MCP server configuration

#### NIM 1B Components (Optional)
- `nim_cache_manifest_1b` - NIM cache for 1B model
- `nim_service_manifest_1b` - NIM service for 1B model
- `keda_scaled_object_manifest_1b` - KEDA scaling configuration
- `create_inference_pod_configmap_1b` - Inference configuration
- `smart_scaler_inference_1b` - Smart Scaler setup
- `create_locust_configmap_1b` - Load test configuration
- `locust_manifest_1b` - Load testing setup

#### NIM 8B Components (Optional)
- `nim_cache_manifest_8b` - NIM cache for 8B model
- `nim_service_manifest_8b` - NIM service for 8B model
- `keda_scaled_object_manifest_8b` - KEDA scaling configuration
- `create_inference_pod_configmap_8b` - Inference configuration
- `smart_scaler_inference_8b` - Smart Scaler setup
- `create_locust_configmap_8b` - Load test configuration
- `locust_manifest_8b` - Load testing setup

### Controlling Execution

To execute specific components, use the `execution_order` variable with a list of components:

```bash
# Execute only GPU operator and monitoring stack
sudo ansible-playbook site.yml \
  --extra-vars "execution_order=['gpu_operator_chart','prometheus_stack']" \
  -e "ngc_api_key=$NGC_API_KEY" \
  -e "ngc_docker_api_key=$NGC_DOCKER_API_KEY" \
  -e "avesha_docker_username=$AVESHA_DOCKER_USERNAME" \
  -e "avesha_docker_password=$AVESHA_DOCKER_PASSWORD" \
  -vv

# Execute only NGINX ingress setup
sudo ansible-playbook site.yml \
  --extra-vars "execution_order=['nginx_ingress_config','nginx_ingress_chart']" \
  -e "ngc_api_key=$NGC_API_KEY" \
  -e "ngc_docker_api_key=$NGC_DOCKER_API_KEY" \
  -e "avesha_docker_username=$AVESHA_DOCKER_USERNAME" \
  -e "avesha_docker_password=$AVESHA_DOCKER_PASSWORD" \
  -vv

# Execute all NIM 70B components
sudo ansible-playbook site.yml \
  --extra-vars "execution_order=['nim_cache_manifest_70b','wait_for_nim_cache_70b','nim_cache_wait_job_70b','nim_service_manifest_70b','keda_scaled_object_manifest_70b','create_inference_pod_configmap_70b','smart_scaler_inference_70b','create_locust_configmap_70b','locust_manifest_70b']" \
  -e "ngc_api_key=$NGC_API_KEY" \
  -e "ngc_docker_api_key=$NGC_DOCKER_API_KEY" \
  -e "avesha_docker_username=$AVESHA_DOCKER_USERNAME" \
  -e "avesha_docker_password=$AVESHA_DOCKER_PASSWORD" \
  -vv
```

> 💡 **Tip**: Components are executed in the order they appear in the list. Make sure to list dependent components in the correct order and include all required credentials.

---

## Destroying the Kubernetes Cluster

To completely remove the Kubernetes cluster and clean up all resources, run the following command from the root directory:

```bash
ansible-playbook kubespray/reset.yml -i inventory/kubespray/inventory.ini
```

This command will:
- Remove all Kubernetes components from the nodes
- Clean up all cluster-related configurations
- Reset the nodes to their pre-Kubernetes state

> ⚠️ **Warning**: This action is irreversible. Make sure to backup any important data before proceeding with the cluster destruction.
