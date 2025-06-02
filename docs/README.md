# Smart Scaler Documentation

## Overview

This documentation directory contains comprehensive guides for deploying and managing Smart Scaler, an intelligent Kubernetes auto-scaling solution with NVIDIA NIM integration.

## Quick Start

For rapid deployment, follow these steps:

1. **Configure your deployment**: Edit `user_input.yml` with your cluster details
2. **Set credentials**: Export required environment variables
3. **Deploy**: Run `./deploy_smartscaler.sh`

See [Deploy SmartScaler Guide](DEPLOY_SMARTSCALER_GUIDE.md) for detailed instructions.

## Documentation Structure

### 🚀 Deployment & Operation

- **[Deploy SmartScaler Guide](DEPLOY_SMARTSCALER_GUIDE.md)** - Complete guide for the master deployment script
  - Prerequisites and system requirements
  - Command line options and deployment modes
  - Environment variables and configuration
  - Troubleshooting and best practices

- **[Configuration Validation](CONFIGURATION_VALIDATION.md)** - Comprehensive validation system guide
  - Automatic and manual validation methods
  - SSH connectivity and privilege escalation testing
  - Common issues and troubleshooting

### ⚙️ Configuration

- **[User Input Configuration](USER_INPUT_CONFIGURATION.md)** - Complete `user_input.yml` configuration guide
  - Structure and required fields
  - Environment-specific configurations
  - Security and networking settings

- **[User Input Reference](USER_INPUT_REFERENCE.md)** - Detailed reference for all configuration options
  - Field-by-field documentation
  - Examples and default values
  - Advanced configuration patterns

- **[Node Configuration Guide](NODE_CONFIGURATION_GUIDE.md)** - Node-specific configuration patterns
  - Root vs non-root user configurations
  - Privilege escalation settings
  - Mixed node configurations

### 🔧 Kubernetes Infrastructure

- **[Kubernetes Installation](KUBERNETES_INSTALLATION.md)** - Kubernetes cluster setup guide
  - Installation methods and requirements
  - Cluster initialization and node joining
  - High availability configurations

- **[Kubernetes Configuration](KUBERNETES_CONFIGURATION.md)** - Cluster configuration and customization
  - Network policies and CNI configuration
  - Storage classes and persistent volumes
  - Resource quotas and limits

- **[Kubernetes Firewall](KUBERNETES_FIREWALL.md)** - Network security and firewall configuration
  - Required ports and protocols
  - Security groups and iptables rules
  - Network troubleshooting

### 🖥️ NVIDIA Integration

- **[NVIDIA Container Runtime](NVIDIA_CONTAINER_RUNTIME.md)** - GPU support and container runtime
  - NVIDIA driver installation
  - Container runtime configuration
  - GPU resource management

## Architecture Overview

Smart Scaler provides:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Load Testing  │────│  Smart Scaler    │────│   NVIDIA NIM    │
│   (Locust)      │    │   Controller     │    │   Inference     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌────────┴────────┐             │
         │              │      KEDA       │             │
         │              │   (Autoscaler)  │             │
         └──────────────┼─────────────────┼─────────────┘
                        │                 │
               ┌────────┴────────┐ ┌─────┴─────┐
               │   Prometheus    │ │ Grafana   │
               │   (Metrics)     │ │(Dashboard)│
               └─────────────────┘ └───────────┘
```

### Key Components

- **Smart Scaler Controller**: Intelligent scaling logic and policy management
- **KEDA**: Kubernetes Event-Driven Autoscaler for responsive scaling
- **NVIDIA NIM**: GPU-accelerated inference services
- **Prometheus**: Metrics collection and storage
- **Grafana**: Monitoring dashboards and visualization
- **Locust**: Load testing and performance validation

## Prerequisites

### System Requirements

- **OS**: Ubuntu 20.04+ or CentOS 7+
- **CPU**: 4+ cores (8+ recommended)
- **Memory**: 8GB+ RAM (16GB+ recommended)
- **Storage**: 100GB+ free space
- **Network**: Internet connectivity for package downloads

### Infrastructure Requirements

- **Kubernetes Cluster**: 1.21+ (deployed automatically or existing)
- **NVIDIA GPUs**: For inference workloads (optional)
- **Load Balancer**: For production deployments
- **Persistent Storage**: For monitoring data and model cache

### Credentials Required

- **NGC API Key**: From NVIDIA NGC (https://ngc.nvidia.com)
- **NGC Docker Key**: For container registry access
- **Avesha Credentials**: Docker registry username and password

## Quick Reference

### Essential Commands

```bash
# Validate configuration
python3 files/validate_config.py

# Full deployment
./deploy_smartscaler.sh

# Deploy only infrastructure
./deploy_smartscaler.sh --skip-apps

# Deploy only applications
./deploy_smartscaler.sh --skip-prereq --skip-k8s

# Remote deployment
./deploy_smartscaler.sh --remote --master-ip 192.168.1.100

# Get help
./deploy_smartscaler.sh --help
```

### Monitoring and Verification

```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Access monitoring
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Check scaling components
kubectl get scaledobjects --all-namespaces
kubectl get hpa --all-namespaces

# View logs
tail -f deployment.log
```

### Troubleshooting Commands

```bash
# Validate SSH connectivity
ssh -i ~/.ssh/k8s_rsa user@node-ip 'echo "Connection test"'

# Check cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Debug deployments
kubectl describe deployment -n smart-scaler
kubectl logs -n smart-scaler deployment/smart-scaler-controller
```

## Configuration Examples

### Minimal Configuration

```yaml
# user_input.yml
kubernetes_deployment:
  enabled: true
  ssh_key_path: "~/.ssh/k8s_rsa"
  default_ansible_user: "ubuntu"
  
  control_plane_nodes:
    - name: "master-1"
      ansible_host: "192.168.1.100"
      ansible_become: true
      ansible_become_method: "sudo"
      ansible_become_user: "root"
```

### Production Configuration

```yaml
# user_input.yml
kubernetes_deployment:
  enabled: true
  ssh_key_path: "~/.ssh/k8s_rsa"
  default_ansible_user: "ubuntu"
  
  control_plane_nodes:
    - name: "master-1"
      ansible_host: "192.168.1.100"
      private_ip: "10.0.1.100"
      ansible_become: true
      ansible_become_method: "sudo"
      ansible_become_user: "root"
    - name: "master-2"
      ansible_host: "192.168.1.101"
      private_ip: "10.0.1.101"
      ansible_become: true
      ansible_become_method: "sudo"
      ansible_become_user: "root"
    - name: "master-3"
      ansible_host: "192.168.1.102"
      private_ip: "10.0.1.102"
      ansible_become: true
      ansible_become_method: "sudo"
      ansible_become_user: "root"
      
  worker_nodes:
    - name: "worker-1"
      ansible_host: "192.168.1.110"
      private_ip: "10.0.1.110"
      ansible_become: true
      ansible_become_method: "sudo"
      ansible_become_user: "root"
    - name: "worker-2"
      ansible_host: "192.168.1.111"
      private_ip: "10.0.1.111"
      ansible_become: true
      ansible_become_method: "sudo"
      ansible_become_user: "root"
```

## Support and Community

### Getting Help

1. **Documentation**: Start with the relevant guide above
2. **Validation**: Run configuration validation for issues
3. **Logs**: Check deployment logs for detailed error information
4. **Community**: Refer to project repository for issues and discussions

### Contributing

Contributions to documentation and code are welcome:

1. **Documentation**: Improve guides and add examples
2. **Configuration**: Share working configuration patterns
3. **Bug Reports**: Report issues with detailed reproduction steps
4. **Feature Requests**: Suggest improvements and new features

### Best Practices

1. **Always validate** configuration before deployment
2. **Use version control** for configuration files
3. **Test in staging** before production deployment
4. **Monitor deployment** logs for early issue detection
5. **Backup configurations** before making changes
6. **Document customizations** for your environment
7. **Regular updates** to keep components current

## File Structure

```
smartscaler-apps-installer/
├── deploy_smartscaler.sh              # Master deployment script
├── user_input.yml                     # Main configuration file
├── files/
│   ├── validate_config.py             # Configuration validator
│   └── [template files]               # Deployment templates
├── docs/                              # Documentation directory
│   ├── DEPLOY_SMARTSCALER_GUIDE.md    # Main deployment guide
│   ├── CONFIGURATION_VALIDATION.md    # Validation guide
│   ├── USER_INPUT_CONFIGURATION.md    # Configuration guide
│   └── [other guides]                 # Additional documentation
├── roles/                             # Ansible roles
├── tasks/                             # Ansible tasks
└── templates/                         # Configuration templates
```

## Next Steps

1. **Read the deployment guide**: [DEPLOY_SMARTSCALER_GUIDE.md](DEPLOY_SMARTSCALER_GUIDE.md)
2. **Configure your deployment**: Edit `user_input.yml`
3. **Validate configuration**: Run `python3 files/validate_config.py`
4. **Deploy Smart Scaler**: Execute `./deploy_smartscaler.sh`
5. **Verify deployment**: Check cluster status and access monitoring

For detailed instructions, follow the [Deploy SmartScaler Guide](DEPLOY_SMARTSCALER_GUIDE.md). 