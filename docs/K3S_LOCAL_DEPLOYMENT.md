# K3s Local Repository Deployment Guide

This document describes the **local repository approach** for K3s deployment, which maintains a local copy of the k3s-ansible repository similar to how kubespray is handled in this system.

## 🎯 **Overview**

Instead of using the k3s-ansible collection via `ansible-galaxy`, this approach:

1. **Clones the k3s-ansible repository locally** into `./k3s-ansible/`
2. **Generates custom inventory and group_vars** from your `user_input.yml`
3. **Uses the local playbooks directly** for deployment
4. **Maintains version control** and consistency

## 🆚 **Local Repository vs Collection Approach**

| Aspect | Local Repository | Collection |
|--------|------------------|------------|
| **Version Control** | ✅ Git-based, version locked | ❌ Latest version always |
| **Customization** | ✅ Can modify playbooks | ❌ Read-only |
| **Offline Support** | ✅ Works without internet | ❌ Requires collection install |
| **Consistency** | ✅ Matches kubespray approach | ❌ Different workflow |
| **Maintenance** | ✅ Update when needed | ❌ Auto-updates |
| **Debugging** | ✅ Full source access | ❌ Limited access |

## 🚀 **Setup Methods**

### **Method 1: Integrated Setup and Deployment (Recommended)**

```bash
# Setup, validate, and deploy in one command
./setup_k3s.sh
```



### **Method 2: Manual Setup**

```bash
# Clone repository manually
git clone https://github.com/k3s-io/k3s-ansible.git

# Generate inventory manually
python3 -c "
# ... inventory generation code
"

# Deploy manually
ansible-playbook -i inventory/k3s/inventory.yml k3s-ansible/playbooks/site.yml
```

## 📁 **Directory Structure**

After setup, you'll have:

```
k3s-automation/
├── k3s-ansible/                    # Local k3s-ansible repository
│   ├── .git/                       # Git repository
│   ├── playbooks/                  # K3s playbooks
│   │   ├── site.yml               # Main deployment playbook
│   │   ├── upgrade.yml            # Upgrade playbook
│   │   └── reset.yml              # Reset playbook
│   ├── inventory/                  # Sample inventory
│   ├── roles/                      # K3s roles
│   └── README.md                   # K3s documentation
├── inventory/
│   └── k3s/                       # Generated K3s inventory
│       ├── inventory.yml           # Custom inventory
│       └── group_vars/
│           └── all.yml             # Custom group variables
├── setup_k3s.sh                    # Integrated setup and deployment script
├── setup_k3s.sh                    # Integrated setup script
└── k3s.yml                         # K3s deployment playbook
```

## 🔧 **Configuration Generation**

### **Inventory Generation**

The setup scripts automatically generate `inventory/k3s/inventory.yml` from your `user_input.yml`:

```yaml
---
k3s_cluster:
  children:
    server:
      hosts:
        192.168.1.10:              # From kubernetes_deployment.control_plane_nodes
          ansible_user: root
          ansible_become: true
          ansible_ssh_private_key_file: /path/to/ssh/key
          private_ip: 192.168.1.10
    agent:
      hosts:
        192.168.1.11:              # From kubernetes_deployment.worker_nodes
          ansible_user: root
          ansible_become: true
          ansible_ssh_private_key_file: /path/to/ssh/key
          private_ip: 192.168.1.11

  vars:
    k3s_version: v1.28.0+k3s1
    service_cidr: 10.43.0.0/16
    cluster_cidr: 10.42.0.0/16
    cni: flannel
    use_external_database: false
```

### **Group Variables Generation**

Automatically generates `inventory/k3s/group_vars/all.yml`:

```yaml
---
# K3s Group Variables
k3s_version: v1.28.0+k3s1
service_cidr: 10.43.0.0/16
cluster_cidr: 10.42.0.0/16
cluster_dns: 10.43.0.10
cni: flannel
use_external_database: false
ansible_python_interpreter: /usr/bin/python3
disable_firewalld: true
disable_swap: true
```

## 🚀 **Deployment Commands**

### **Using Local Repository**

```bash
# Basic deployment
ansible-playbook -i inventory/k3s/inventory.yml k3s-ansible/playbooks/site.yml

# With verbose output
ansible-playbook -i inventory/k3s/inventory.yml k3s-ansible/playbooks/site.yml -vvv

# With custom variables
ansible-playbook -i inventory/k3s/inventory.yml k3s-ansible/playbooks/site.yml \
  -e "k3s_version=v1.29.0+k3s1" \
  -e "cni=calico"
```

### **Using Generated Playbooks**

```bash
# Use the integrated k3s.yml playbook
ansible-playbook k3s.yml

# Use the K3s role
ansible-playbook site.yml  # If k3s_deployment.enabled: true
```

## 🔄 **Repository Management**

### **Update Local Repository**

```bash
cd k3s-ansible
git fetch origin
git reset --hard origin/master
cd ..
```

### **Pin to Specific Version**

```bash
cd k3s-ansible
git checkout v1.28.0  # or specific tag
cd ..
```

### **Custom Modifications**

```bash
cd k3s-ansible
# Make your custom changes
git add .
git commit -m "Custom modifications for our environment"
cd ..
```

## 📋 **Advanced Configuration**

### **Custom Playbook Modifications**

You can modify the local k3s-ansible playbooks:

```bash
# Edit the main deployment playbook
vim k3s-ansible/playbooks/site.yml

# Add custom roles or tasks
vim k3s-ansible/roles/custom/tasks/main.yml
```

### **Custom Inventory Variables**

Extend the generated group_vars:

```yaml
# inventory/k3s/group_vars/all.yml
---
# Generated variables
k3s_version: v1.28.0+k3s1
service_cidr: 10.43.0.0/16
cluster_cidr: 10.42.0.0/16

# Custom additions
custom_feature: true
debug_mode: true
log_level: debug
```

### **Multi-Environment Support**

Create environment-specific inventories:

```bash
# Development environment
cp inventory/k3s/inventory.yml inventory/k3s/inventory-dev.yml

# Production environment
cp inventory/k3s/inventory.yml inventory/k3s/inventory-prod.yml

# Deploy to specific environment
ansible-playbook -i inventory/k3s/inventory-prod.yml k3s-ansible/playbooks/site.yml
```

## 🧪 **Testing and Validation**

### **Dry Run**

```bash
# Check what would be executed
ansible-playbook -i inventory/k3s/inventory.yml k3s-ansible/playbooks/site.yml --check

# Syntax check
ansible-playbook -i inventory/k3s/inventory.yml k3s-ansible/playbooks/site.yml --syntax-check
```

### **Validation Scripts**

```bash
# Validate configuration and setup
./setup_k3s.sh

# Test SSH connectivity
ansible -i inventory/k3s/inventory.yml all -m ping
```

## 🔍 **Troubleshooting**

### **Common Issues**

1. **Repository Not Found**
   ```bash
   # Re-clone the repository
   rm -rf k3s-ansible
   git clone https://github.com/k3s-io/k3s-ansible.git
   ```

2. **Inventory Mismatch**
   ```bash
   # Regenerate inventory
   ./setup_k3s.sh
   ```

3. **Playbook Errors**
   ```bash
   # Check playbook syntax
   ansible-playbook -i inventory/k3s/inventory.yml k3s-ansible/playbooks/site.yml --syntax-check
   
   # Enable verbose output
   ansible-playbook -i inventory/k3s/inventory.yml k3s-ansible/playbooks/site.yml -vvv
   ```

### **Debug Mode**

```bash
# Maximum verbosity
ansible-playbook -i inventory/k3s/inventory.yml k3s-ansible/playbooks/site.yml -vvvv

# Debug specific tasks
ansible-playbook -i inventory/k3s/inventory.yml k3s-ansible/playbooks/site.yml \
  -e "ansible_verbosity=4"
```

## 📚 **Best Practices**

1. **Version Control**: Commit your custom inventory and group_vars
2. **Repository Updates**: Update k3s-ansible repository regularly
3. **Testing**: Test changes in development environment first
4. **Backup**: Keep backups of working configurations
5. **Documentation**: Document any custom modifications

## 🔗 **Related Documentation**

- [K3s Deployment Guide](K3S_DEPLOYMENT.md) - General K3s deployment
- [Kubernetes Configuration](KUBERNETES_CONFIGURATION.md) - Node configuration
- [User Input Configuration](USER_INPUT_CONFIGURATION.md) - Configuration format

## 🆘 **Support**

For issues with the local repository approach:

1. Check the generated inventory and group_vars files
2. Verify the k3s-ansible repository is properly cloned
3. Test SSH connectivity to all nodes
4. Review the k3s-ansible documentation in `./k3s-ansible/README.md`
5. Check the [k3s-ansible repository](https://github.com/k3s-io/k3s-ansible) for updates
