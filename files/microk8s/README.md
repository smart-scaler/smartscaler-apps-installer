# MicroK8s Configuration Scripts

This directory contains scripts and configuration utilities for MicroK8s deployment.

## Files Overview

### `generate_microk8s_config.py`
Generates MicroK8s-specific inventory and group variables for Ansible deployment.

**Usage:**
```bash
python3 files/microk8s/generate_microk8s_config.py
```

**Generated Files:**
- `inventory/microk8s/inventory.yml` - Ansible inventory for MicroK8s nodes
- `inventory/microk8s/group_vars/all.yml` - MicroK8s-specific group variables

**Requirements:**
- `user_input.yml` must contain both `kubernetes_deployment` and `microk8s_deployment` sections
- Python 3 with `pyyaml` and `jinja2` packages

### `test_ssh_connectivity.py`
Tests SSH connectivity to all nodes defined in the configuration before deployment.

**Usage:**
```bash
python3 files/microk8s/test_ssh_connectivity.py
```

**Features:**
- Tests SSH connection to all control plane and worker nodes
- Validates SSH key permissions and accessibility
- Provides detailed error reporting for failed connections

## Configuration Dependencies

These scripts depend on the configuration in `user_input.yml`:

### Required Sections:
1. **`kubernetes_deployment`** - Node configuration (reused for MicroK8s)
   - `control_plane_nodes` - List of control plane nodes
   - `worker_nodes` - List of worker nodes (optional)
   - `ssh_key_path` - Path to SSH private key
   - `default_ansible_user` - Default SSH user

2. **`microk8s_deployment`** - MicroK8s-specific configuration
   - `enabled` - Must be `true` to enable MicroK8s deployment
   - `microk8s_channel` - Snap channel for MicroK8s installation
   - `microk8s_config` - Detailed MicroK8s configuration

## MicroK8s-Specific Features

### Add-ons Management
- Essential add-ons: `dns`, `storage`, `ingress` (enabled by default)
- Optional add-ons: `dashboard`, `metrics-server`, `prometheus`, `gpu`, etc.

### Multi-Node Clustering
- Automatic cluster formation for multi-node setups
- Support for both control plane and worker nodes
- Configurable join timeouts and clustering options

### High Availability
- Support for HA configurations with 3+ control plane nodes
- Dqlite datastore for HA setups
- Automatic HA detection and configuration

### NVIDIA GPU Support
- Automatic NVIDIA GPU detection and configuration
- Integration with existing Jetson and NVIDIA prerequisite roles
- GPU add-on enablement for NVIDIA devices

## Integration with Existing Infrastructure

### Jetson Support
MicroK8s deployment integrates with existing Jetson prerequisite roles:
- Automatic Jetson device detection
- jetson-stats installation and configuration
- jtop socket verification

### NVIDIA Support
Integration with NVIDIA prerequisite roles:
- NVIDIA GPU detection
- Container runtime configuration
- NVIDIA device plugin setup

## Generated Inventory Structure

The generated inventory uses the `microk8s_cluster` group:

```yaml
microk8s_cluster:
  children:
    all:
      hosts:
        <node_ip>:
          ansible_user: <user>
          ansible_become: true
          # ... other node-specific vars
  vars:
    microk8s_channel: <channel>
    microk8s_addons: [dns, storage, ingress]
    # ... other MicroK8s-specific vars
```

## Deployment Process

1. Configure `user_input.yml` with node and MicroK8s settings
2. Run `generate_microk8s_config.py` to create inventory files
3. Run `test_ssh_connectivity.py` to verify node access
4. Execute `setup_microk8s.sh` or `ansible-playbook microk8s.yml` for deployment

## Troubleshooting

### SSH Connectivity Issues
- Verify SSH key permissions (600)
- Check SSH key path in configuration
- Ensure target nodes are accessible
- Confirm user accounts exist on target nodes
- Verify SSH service is running

### Configuration Issues
- Ensure all required sections exist in `user_input.yml`
- Validate YAML syntax
- Check node IP addresses and credentials
- Verify snap and MicroK8s channel availability

### Deployment Issues
- Check Ansible logs in `output/ansible.log`
- Verify snap installation on target nodes
- Check network connectivity between nodes
- Validate firewall settings for MicroK8s ports (16443, 10250, etc.)

## Port Requirements

MicroK8s requires the following ports to be open:
- **16443/tcp** - MicroK8s API server
- **10250/tcp** - Kubelet API
- **10255/tcp** - Kubelet readonly API (optional)
- **25000/tcp** - MicroK8s cluster agent
- **8472/udp** - Flannel VXLAN (if using Flannel CNI)

## Storage and Networking

### Default Network Configuration
- Service CIDR: `10.152.183.0/24`
- Pod CIDR: `10.1.0.0/16`
- API Port: `16443`

### Storage
- Default storage class: `microk8s-hostpath`
- Local path provisioner included
- Support for additional storage backends via add-ons
