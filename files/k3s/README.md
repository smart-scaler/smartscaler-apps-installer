# K3s Files Directory

This directory contains all K3s-related files and scripts for the automation system.

## 📁 Directory Structure

```
files/k3s/
├── README.md                    # This file
├── generate_k3s_config.py       # K3s configuration generator
├── test_ssh_connectivity.py     # SSH connectivity tester
└── update_k3s_ansible.sh       # K3s-ansible update script
```

## 🔧 Files Description

### **generate_k3s_config.py**
- Generates K3s inventory and configuration files
- Reads from `user_input.yml` and creates necessary Ansible files
- **Usage**: Called automatically by `setup_k3s.sh`

### **test_ssh_connectivity.py**
- Tests SSH connectivity to all nodes defined in configuration
- Verifies SSH keys and user access before deployment
- **Usage**: Called automatically by `setup_k3s.sh`

### **update_k3s_ansible.sh**
- Manually updates the k3s-ansible repository
- Preserves customizations (like Jetson roles)
- Creates backups before updating
- **Usage**: Run manually when you want to update k3s-ansible

## 🚀 How to Use

### **Automatic Usage**
Most files are used automatically by the main `setup_k3s.sh` script:
```bash
./setup_k3s.sh
```

### **Manual Update of k3s-ansible**
To manually update the k3s-ansible repository:
```bash
./files/k3s/update_k3s_ansible.sh
```

### **Manual Testing**
To test SSH connectivity manually:
```bash
python3 files/k3s/test_ssh_connectivity.py
```

To generate K3s configuration manually:
```bash
python3 files/k3s/generate_k3s_config.py
```

## 📋 Notes

- **k3s-ansible**: Remains in the root directory for Ansible role access
- **Local Copy**: The system maintains a local copy of k3s-ansible without git tracking
- **Customizations**: Jetson roles and other customizations are automatically preserved
- **Updates**: Use the update script to get the latest k3s-ansible version

## 🔗 Related Files

- **Root Directory**: `setup_k3s.sh` (main deployment script)
- **Root Directory**: `k3s-ansible/` (local copy of k3s-ansible)
- **Configuration**: `user_input.yml` (K3s deployment settings)
- **Roles**: `roles/jetson_prerequisites/` (Jetson detection role)
