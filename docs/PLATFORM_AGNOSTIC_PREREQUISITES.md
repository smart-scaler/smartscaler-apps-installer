# 🚀 Platform-Agnostic Prerequisites (Jetson + NVIDIA)

## Overview

Both the **Jetson Prerequisites** and **NVIDIA Prerequisites** roles have been restructured to work for **BOTH** K3s and Kubespray Kubernetes deployments. This ensures that Jetson device detection, `jetson-stats` installation, and NVIDIA GPU support works regardless of which Kubernetes distribution you choose.

## 🔄 What Changed

### Before (Platform-Specific)
```yaml
# Only worked for K3s deployments
k3s_deployment:
  jetson_prerequisites:
    enabled: true
    # ... configuration
  nvidia_runtime:
    enabled: true
    # ... configuration
```

### After (Platform-Agnostic)
```yaml
# Works for ALL Kubernetes deployments
jetson_prerequisites:
  enabled: true
  # ... configuration

nvidia_prerequisites:
  enabled: true
  # ... configuration
```

## 🎯 Benefits

1. **Universal Support**: Jetson and NVIDIA functionality works for K3s, Kubespray, and any future Kubernetes distributions
2. **Consistent Configuration**: Same Jetson and NVIDIA settings apply regardless of deployment method
3. **Reusable Roles**: The roles can be used independently or integrated into any deployment workflow
4. **Future-Proof**: Adding new Kubernetes distributions doesn't require role changes

## 🏗️ Architecture

```
user_input.yml
├── jetson_prerequisites          # 🆕 Global Jetson configuration
│   ├── enabled: true
│   ├── jetson_stats: {...}
│   └── detection_methods: [...]
├── nvidia_prerequisites          # 🆕 Global NVIDIA configuration
│   ├── enabled: true
│   ├── container_runtime: {...}
│   ├── detection: {...}
│   └── verification: {...}
├── k3s_deployment               # K3s-specific settings
│   └── # ... K3s configuration
└── kubespray_deployment         # Kubespray-specific settings
    └── # ... Kubespray configuration
```

## 🚀 Usage Examples

### 1. Independent Prerequisites Setup (Any Platform)
```bash
# Test Jetson role independently
ansible-playbook test_jetson_role.yml -i inventory.yml

# Test NVIDIA role independently
ansible-playbook test_nvidia_role.yml -i inventory.yml

# Use in custom playbooks
ansible-playbook my_custom_playbook.yml -i inventory.yml
```

### 2. K3s Deployment with Prerequisites
```bash
# Both Jetson and NVIDIA roles run automatically during K3s setup
./setup_k3s.sh
```

### 3. Kubespray Deployment with Prerequisites
```bash
# Both roles can be integrated into Kubespray playbooks
ansible-playbook kubespray/cluster.yml -i inventory.yml
```

## 🔧 Configuration

Both Jetson and NVIDIA configurations are now at the global level in `user_input.yml`:

```yaml
# Global Jetson Configuration (Platform-Agnostic)
jetson_prerequisites:
  enabled: true
  
  jetson_stats:
    force_reinstall: false
    upgrade: true
    python_version: "python3"
    pip_extra_args: "--upgrade"
  
  detection_methods:
    - device_tree_model
    - device_tree_compatible
    - nv_tegra_release
    - system_architecture
  
  jtop_test_timeout: 5
  verbose: false

# Global NVIDIA Configuration (Platform-Agnostic)
nvidia_prerequisites:
  enabled: true
  
  container_runtime:
    install_toolkit: true
    configure_containerd: true
    create_runtime_class: true
    architecture: "amd64"
  
  detection:
    enabled: true
    methods:
      - nvidia_smi
      - lspci
      - device_files
      - kernel_modules
  
  verification:
    test_gpu_access: true
    create_test_pod: true
    timeout: 300
```

## 📁 File Structure

```
roles/jetson_prerequisites/          # Platform-agnostic Jetson role
├── defaults/main.yml               # Default configuration
├── tasks/main.yml                  # Main tasks
├── meta/main.yml                   # Role metadata
├── README.md                       # Documentation
└── example.yml                     # Example playbook

roles/nvidia_prerequisites/          # Platform-agnostic NVIDIA role
├── defaults/main.yml               # Default configuration
├── tasks/main.yml                  # Main tasks
├── meta/main.yml                   # Role metadata
├── README.md                       # Documentation
└── example.yml                     # Example playbook

test_jetson_role.yml               # Independent Jetson testing playbook
test_nvidia_role.yml               # Independent NVIDIA testing playbook
```

## 🔍 Detection Methods

The Jetson role uses multiple detection methods to identify Jetson devices:

1. **Device Tree Model**: `/proc/device-tree/model`
2. **Device Tree Compatible**: `/proc/device-tree/compatible`
3. **NVIDIA Tegra Release**: `/etc/nv_tegra_release`
4. **System Architecture**: System architecture checks

The NVIDIA role uses multiple detection methods to identify NVIDIA GPUs:

1. **nvidia-smi**: Check if NVIDIA drivers are installed and GPUs are accessible
2. **lspci**: Scan PCI bus for NVIDIA devices
3. **Device Files**: Look for `/dev/nvidia*` device files
4. **Kernel Modules**: Check for loaded NVIDIA kernel modules

## ✅ Verification

After running the Jetson role, verify it worked by checking:

1. **jtop.sock**: `/run/jtop.sock` exists and is accessible
2. **jtop Command**: `jtop` command works
3. **Service Status**: `jtop` service is running
4. **Container Access**: Containers can access `jtop.sock`

After running the NVIDIA role, verify it worked by checking:

1. **Container Runtime**: `nvidia-container-runtime` is installed and working
2. **Runtime Class**: Kubernetes RuntimeClass `nvidia` is created
3. **GPU Access**: Containers can access GPU resources
4. **Verification**: Test containers can run with GPU access

## 🚨 Troubleshooting

### Jetson Not Detected
- Check detection methods in configuration
- Verify device tree files exist
- Check system architecture compatibility

### jetson-stats Installation Failed
- Verify Python version compatibility
- Check pip installation permissions
- Review pip extra arguments

### jtop.sock Not Accessible
- Check file permissions
- Verify service is running
- Test container access

### NVIDIA GPUs Not Detected
- Check detection methods in configuration
- Verify NVIDIA drivers are installed
- Check if GPUs are physically present

### NVIDIA Container Runtime Installation Failed
- Check internet connectivity
- Verify package repository access
- Review architecture settings

### Containerd Configuration Issues
- Check containerd service status
- Verify configuration file syntax
- Review backup and restore process

## 🔮 Future Enhancements

- Support for additional Jetson models
- Integration with NVIDIA GPU Operator
- Enhanced monitoring and alerting
- Multi-architecture support (ARM64, x86_64)
- Support for additional NVIDIA GPU models
- Enhanced GPU monitoring and metrics
- Multi-GPU node support
- GPU scheduling optimization

## 📚 Related Documentation

- [Jetson Role README](../roles/jetson_prerequisites/README.md)
- [NVIDIA Role README](../roles/nvidia_prerequisites/README.md)
- [K3s Deployment Guide](K3S_DEPLOYMENT.md)
- [Kubespray Documentation](../kubespray/docs/)
- [GPU Operator Setup](GPU_OPERATOR_SETUP.md)

---

**🎯 Key Takeaway**: Both Jetson and NVIDIA functionality are now **platform-agnostic** and work seamlessly with any Kubernetes distribution!
