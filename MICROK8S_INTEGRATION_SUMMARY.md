# MicroK8s Installation Guide

## Overview

This guide provides step-by-step instructions for installing MicroK8s using the smartscaler-apps-installer. MicroK8s is a lightweight Kubernetes distribution that's perfect for edge computing, development, and production workloads on cloud instances.

## Features

- **External Access**: Configured for access via public IP
- **ARM64 Support**: Optimized for ARM-based systems including NVIDIA Jetson
- **GPU Support**: Automatic NVIDIA GPU detection and configuration
- **Snap-based**: Easy installation and management via snap packages
- **Add-ons**: Rich ecosystem of add-ons (DNS, storage, ingress, dashboard, etc.)

## Installation Steps

Follow these steps in order to install MicroK8s on your remote machine:

### 1. SSH into the Machine

```bash
ssh root@<your-public-ip>
```

### 2. Configure SSH Access

Set up SSH keys for local Ansible access:

```bash
# Generate SSH key if it doesn't exist
ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ""

# Add the public key to authorized_keys for root access
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
chmod 700 /root/.ssh
```

### 3. Clone the Repository

```bash
git clone https://github.com/your-org/smartscaler-apps-installer.git
cd smartscaler-apps-installer
```

### 4. Initialize Python Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate
```

### 5. Install Ansible

```bash
pip install ansible
```

### 6. Run the Setup Script

```bash
./setup_microk8s.sh
```

This script will:
- Validate your configuration
- Check SSH connectivity
- Install required Ansible collections
- Prepare the deployment environment

### 7. Deploy MicroK8s

```bash
ansible-playbook microk8s.yml
```

This will:
- Install and configure MicroK8s
- Set up external access via your public IP
- Enable essential add-ons (DNS, storage, ingress)
- Generate a kubeconfig file for external access

## Post-Installation

### External Access

After installation, you can access your cluster externally:

1. **Copy the kubeconfig** to your local machine:
   ```bash
   scp root@<your-public-ip>:/root/smartscaler-apps-installer/output/kubeconfig ~/.kube/microk8s-config
   ```

2. **Test external access**:
   ```bash
   export KUBECONFIG=~/.kube/microk8s-config
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

### Firewall Configuration

**Important**: Ensure port 16443 is open in your cloud security group/firewall for external API access.

### Verification Commands

```bash
# Check cluster status
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Check cluster info
kubectl cluster-info

# Check available add-ons (run on the server)
microk8s status
```

## Configuration

The installation uses configuration from `user_input.yml`. Key MicroK8s settings:

```yaml
microk8s_deployment:
  enabled: true
  microk8s_channel: "latest/stable"
  microk8s_config:
    addons: ['dns', 'storage', 'ingress']
    additional_addons: []
    container_runtime:
      enable_nvidia_support: true
```

## Troubleshooting

### Common Issues

1. **Port 16443 blocked**: Check your cloud security group/firewall
2. **SSH connectivity**: Ensure SSH keys are properly configured
3. **Permission denied**: Make sure you're running as root or have sudo access

### Log Locations

- Ansible logs: `output/ansible.log`
- MicroK8s logs: `sudo journalctl -u snap.microk8s.*`

### Support Resources

- [MicroK8s Documentation](https://microk8s.io/docs)
- [Ubuntu MicroK8s Tutorial](https://ubuntu.com/tutorials/install-a-local-kubernetes-with-microk8s)

## What Gets Installed

- **MicroK8s**: Latest stable version via snap
- **Essential Add-ons**: DNS, storage, ingress
- **NVIDIA Support**: GPU add-on (if NVIDIA GPU detected)
- **External Access**: API server configured for public IP access
- **kubectl**: Command-line tool with alias configuration

## Next Steps

After successful installation:

1. Deploy your applications using `kubectl`
2. Configure additional add-ons as needed
3. Set up monitoring and logging
4. Consider adding more nodes for high availability

Your MicroK8s cluster is now ready for production workloads with external access capabilities!
