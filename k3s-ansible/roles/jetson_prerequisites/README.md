# Jetson Prerequisites Role

This Ansible role automatically detects Jetson devices and installs the `jetson-stats` package for monitoring and statistics.

**🚀 Platform Support**: This role works for **BOTH** K3s and Kubespray Kubernetes deployments!

## Features

- **Automatic Jetson Detection**: Uses multiple methods to identify Jetson devices
- **jetson-stats Installation**: Installs and configures jetson-stats for system monitoring
- **Smart Detection**: Works with various Jetson models (Nano, Xavier, Orin, etc.)
- **Verification**: Tests the installation and provides feedback

## Jetson Detection Methods

The role uses several methods to detect Jetson devices:

1. **Device Tree Model** (`/proc/device-tree/model`)
2. **Device Tree Compatible** (`/proc/device-tree/compatible`)
3. **NVIDIA Tegra Release** (`/etc/nv_tegra_release`)
4. **System Architecture** checks

## Requirements

- Ansible 2.9+
- Python 3.x on target nodes
- `pip` package manager
- Root/sudo access for package installation

## Role Variables

### Main Configuration

```yaml
jetson_prerequisites:
  enabled: true  # Enable/disable the role
```

### jetson-stats Options

```yaml
jetson_prerequisites:
  jetson_stats:
    force_reinstall: false    # Force reinstallation
    upgrade: true            # Upgrade to latest version
    python_version: "python3" # Python version to use
    pip_extra_args: "--upgrade" # Additional pip arguments
```

### Detection Options

```yaml
jetson_prerequisites:
  detection_methods:
    - device_tree_model
    - device_tree_compatible
    - nv_tegra_release
    - system_architecture
  
  jtop_test_timeout: 5  # Timeout for jtop test (seconds)
  verbose: false         # Verbose output
```

## Usage

### Basic Usage

```yaml
- hosts: all
  roles:
    - jetson_prerequisites
```

### With Custom Configuration

```yaml
- hosts: all
  vars:
    jetson_prerequisites:
      enabled: true
      jetson_stats:
        force_reinstall: true
        upgrade: true
  roles:
    - jetson_prerequisites
```

### In a Playbook

```yaml
- name: Configure Jetson devices
  hosts: jetson_nodes
  become: true
  roles:
    - jetson_prerequisites
```

## What Gets Installed

- **jetson-stats**: Python package for Jetson monitoring
- **jtop**: Command-line tool for real-time system monitoring
- **Python dependencies**: Required packages for jetson-stats

## Verification

The role automatically verifies the installation:

1. **Import Test**: Tests if `jtop` module can be imported
2. **Command Test**: Tests `jtop --no-ui` command functionality
3. **Version Check**: Displays installed jetson-stats version

## Example Output

```
TASK [jetson_prerequisites : Display Jetson detection results]
ok: [jetson-nano] => {
    "msg": [
        "Jetson Detection Results:",
        "- Device Tree Model: NVIDIA Jetson Nano Developer Kit",
        "- Device Tree Compatible: nvidia,tegra210",
        "- NVIDIA Tegra Release: R32 (release), REVISION: 6.3",
        "- Tegra Release File Exists: true",
        "- Is Jetson Device: true"
    ]
}

TASK [jetson_prerequisites : Display jetson-stats verification result]
ok: [jetson-nano] => {
    "msg": "jetson-stats version: 3.1.0"
}
```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure the role runs with `become: true`
2. **Python Not Found**: Verify Python 3.x is installed
3. **pip Not Available**: Install pip if not present
4. **Detection Fails**: Check if device tree files are accessible

### Manual Verification

```bash
# Check if jetson-stats is installed
python3 -c "import jtop; print(jtop.__version__)"

# Test jtop command
jtop --no-ui

# Check Jetson hardware
cat /proc/device-tree/model
cat /etc/nv_tegra_release
```

## Dependencies

- No external role dependencies
- Requires `pip` module (built into Ansible)

## License

This role is part of the k3s-automation project.

## Support

For issues and questions, please refer to the main project documentation.
