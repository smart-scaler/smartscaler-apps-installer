# Smart Scaler Configuration Validation Guide

## Overview

The configuration validation system ensures that your Smart Scaler deployment configuration is correct before attempting deployment. It validates YAML syntax, node configurations, SSH connectivity, and privilege escalation settings.

## Components

### validate_config.py

**Location**: `files/validate_config.py`

A comprehensive Python script that validates all aspects of your `user_input.yml` configuration file.

### Integrated Validation

The validation is automatically integrated into `deploy_smartscaler.sh` and runs before any deployment steps.

## Validation Features

### 1. YAML Syntax Validation
- Ensures `user_input.yml` is valid YAML
- Reports syntax errors with line numbers
- Validates file existence and readability

### 2. Required Fields Validation
- Checks for mandatory configuration fields
- Validates node names and IP addresses
- Ensures proper structure for control plane and worker nodes

### 3. IP Address Validation
- Validates IPv4 address format
- Checks both `ansible_host` and `private_ip` fields
- Warns about invalid IP formats

### 4. SSH Key Validation
- Verifies SSH private key exists
- Checks SSH key file permissions (should be 600)
- Validates corresponding public key existence
- Reports permission issues

### 5. Node Configuration Validation
- Validates privilege escalation settings
- Checks consistency of `ansible_become` configurations
- Ensures proper user configuration for non-root access

### 6. SSH Connectivity Testing
- Tests actual SSH connections to all nodes
- Verifies key-based authentication
- Tests sudo access for non-root users
- Reports connection failures with details

## Usage Methods

### 1. Automatic Validation (Integrated)

The validation runs automatically when using `deploy_smartscaler.sh`:

```bash
# Validation runs automatically
./deploy_smartscaler.sh

# Skip validation (not recommended)
./deploy_smartscaler.sh --skip-validation
```

### 2. Manual Validation (Interactive)

Run validation independently with interactive prompts:

```bash
python3 files/validate_config.py
```

**Interactive Features**:
- Prompts for SSH connectivity testing
- Detailed error and warning explanations
- Step-by-step validation process

### 3. Manual Validation (Non-Interactive)

For automation or CI/CD pipelines:

```bash
python3 -c "
import sys
sys.path.insert(0, '.')
exec(open('files/validate_config.py').read().replace(
    'test_connectivity = input(\"\\nTest SSH connectivity to nodes? [y/N]: \").lower().startswith(\'y\')',
    'test_connectivity = True'
))
"
```

## Validation Output

### Success Output Example

```bash
[INFO] Smart Scaler Configuration Validator
==================================================
[SUCCESS] YAML syntax is valid
[INFO] 

Validating Kubernetes deployment configuration...
[INFO] Validating 1 control plane node(s)...
[INFO] Validating control plane node 1: master-1
[INFO] Validating 2 worker node(s)...
[INFO] Validating worker node 1: worker-1
[INFO] Validating worker node 2: worker-2
[SUCCESS] SSH key configuration valid: /home/user/.ssh/k8s_rsa
[INFO] 

Testing SSH connectivity...
[SUCCESS] SSH connectivity successful: master-1 (ubuntu@192.168.1.100)
[SUCCESS] Sudo privilege escalation successful: master-1
[SUCCESS] SSH connectivity successful: worker-1 (ubuntu@192.168.1.101)
[SUCCESS] Sudo privilege escalation successful: worker-1
[SUCCESS] SSH connectivity successful: worker-2 (ubuntu@192.168.1.102)
[SUCCESS] Sudo privilege escalation successful: worker-2

==================================================
VALIDATION RESULTS
==================================================
[SUCCESS] Configuration validation passed!
[SUCCESS] Ready for deployment.

Next steps:
1. Run deployment: ./deploy_smartscaler.sh
2. Or run individual components:
   - Prerequisites only: ./deploy_smartscaler.sh --skip-k8s --skip-apps
   - Kubernetes only: ./deploy_smartscaler.sh --skip-prereq --skip-apps
   - Applications only: ./deploy_smartscaler.sh --skip-prereq --skip-k8s
```

### Error Output Example

```bash
[INFO] Smart Scaler Configuration Validator
==================================================
[SUCCESS] YAML syntax is valid
[INFO] 

Validating Kubernetes deployment configuration...
[INFO] Validating 1 control plane node(s)...
[INFO] Validating control plane node 1: master-1
[WARNING] Invalid IP address format for master-1.ansible_host: invalid-ip
[WARNING] Node 'master-1' uses non-root user 'ubuntu' but ansible_become is not enabled
[ERROR] SSH connectivity failed: master-1 (ubuntu@192.168.1.100)
[ERROR]   Error: Permission denied (publickey).

==================================================
VALIDATION RESULTS
==================================================
[WARNING] Found 2 warning(s):
[WARNING]   • Control plane node 1: Consider using valid IP address for ansible_host: invalid-ip
[WARNING]   • Control plane node 1: Node 'master-1' uses non-root user 'ubuntu' but ansible_become is not enabled
[ERROR] Found 1 error(s):
[ERROR]   • SSH connectivity failed for: master-1
[ERROR] Please fix the errors before proceeding with deployment.
```

## Configuration Requirements

### Basic Node Configuration

```yaml
kubernetes_deployment:
  enabled: true
  ssh_key_path: "~/.ssh/k8s_rsa"
  default_ansible_user: "ubuntu"
  
  control_plane_nodes:
    - name: "master-1"                    # Required: Node name
      ansible_host: "192.168.1.100"      # Required: IP address or hostname
      ansible_user: "ubuntu"             # Optional: Defaults to default_ansible_user
      ansible_become: true               # Required for non-root users
      ansible_become_method: "sudo"      # Required when ansible_become is true
      ansible_become_user: "root"        # Required when ansible_become is true
      private_ip: "10.0.1.100"          # Optional: Internal cluster IP
```

### Validation Rules

#### Required Fields
- `name`: Unique identifier for the node
- `ansible_host`: IP address or hostname for SSH connection

#### Conditional Requirements
For non-root users (`ansible_user` != "root"):
- `ansible_become: true`
- `ansible_become_method: "sudo"`
- `ansible_become_user: "root"`

#### Optional Fields
- `ansible_user`: Defaults to `default_ansible_user`
- `private_ip`: Internal IP for cluster communication

## Common Configuration Patterns

### 1. Root User Access (Simple)

```yaml
control_plane_nodes:
  - name: "master-1"
    ansible_host: "192.168.1.100"
    ansible_user: "root"
    # No privilege escalation needed
```

**Validation**: ✅ Passes without privilege escalation checks

### 2. Non-Root User with Sudo (Recommended)

```yaml
control_plane_nodes:
  - name: "master-1"
    ansible_host: "192.168.1.100"
    ansible_user: "ubuntu"
    ansible_become: true
    ansible_become_method: "sudo"
    ansible_become_user: "root"
```

**Validation**: ✅ Tests SSH + sudo access

### 3. Mixed Configuration

```yaml
control_plane_nodes:
  - name: "master-1"
    ansible_host: "192.168.1.100"
    ansible_user: "root"
  - name: "master-2"
    ansible_host: "192.168.1.101"
    ansible_user: "ubuntu"
    ansible_become: true
    ansible_become_method: "sudo"
    ansible_become_user: "root"
```

**Validation**: ✅ Handles different access methods per node

### 4. Default User Configuration

```yaml
kubernetes_deployment:
  default_ansible_user: "ubuntu"
  
  control_plane_nodes:
    - name: "master-1"
      ansible_host: "192.168.1.100"
      # Inherits default_ansible_user
      ansible_become: true
      ansible_become_method: "sudo"
      ansible_become_user: "root"
```

**Validation**: ✅ Uses default user when not specified

## SSH Key Management

### SSH Key Requirements

1. **Private Key**: Must exist at specified path
2. **Permissions**: Private key should be 600 (owner read/write only)
3. **Public Key**: Should exist with `.pub` extension
4. **Authentication**: Key must be added to remote nodes

### SSH Key Setup

```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/k8s_rsa -N ""

# Set proper permissions
chmod 600 ~/.ssh/k8s_rsa
chmod 644 ~/.ssh/k8s_rsa.pub

# Copy to all nodes
ssh-copy-id -i ~/.ssh/k8s_rsa.pub ubuntu@192.168.1.100
ssh-copy-id -i ~/.ssh/k8s_rsa.pub ubuntu@192.168.1.101
```

### Validation Checks

The validator performs these SSH-related checks:

1. **Key Existence**: Verifies both private and public keys exist
2. **Permissions**: Checks private key has correct permissions (600)
3. **Connectivity**: Tests actual SSH connection using the key
4. **Authentication**: Verifies key-based login works
5. **Privilege Escalation**: Tests sudo access for non-root users

## Privilege Escalation Validation

### Sudo Configuration Requirements

For non-root users, the validator tests sudo access:

```bash
# Test command executed by validator
ssh -i ~/.ssh/k8s_rsa ubuntu@192.168.1.100 'sudo whoami'
```

### Setting Up Passwordless Sudo

On each remote node, configure passwordless sudo:

```bash
# Add user to sudoers (on remote node)
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ubuntu

# Verify configuration
sudo -n whoami  # Should not prompt for password
```

### Common Sudo Issues

#### Issue: Password Prompt
```bash
[ERROR] Sudo privilege escalation failed: master-1
[ERROR]   Error: sudo: a password is required
```

**Solution**: Configure passwordless sudo (see above)

#### Issue: User Not in Sudoers
```bash
[ERROR] Sudo privilege escalation failed: master-1
[ERROR]   Error: ubuntu is not in the sudoers file
```

**Solution**: Add user to sudoers group or file

## Troubleshooting Validation Issues

### Common Validation Errors

#### 1. YAML Syntax Errors

**Error**: `YAML syntax error: mapping values are not allowed here`

**Solution**:
```bash
# Check YAML syntax
python3 -c "import yaml; yaml.safe_load(open('user_input.yml'))"

# Fix indentation and syntax errors
# Use a YAML validator or editor with YAML support
```

#### 2. SSH Connection Failures

**Error**: `SSH connectivity failed: master-1 (ubuntu@192.168.1.100)`

**Solutions**:
```bash
# Test SSH manually
ssh -i ~/.ssh/k8s_rsa ubuntu@192.168.1.100

# Check SSH key permissions
ls -la ~/.ssh/k8s_rsa  # Should show -rw-------

# Fix permissions if needed
chmod 600 ~/.ssh/k8s_rsa

# Copy SSH key if not present on remote
ssh-copy-id -i ~/.ssh/k8s_rsa.pub ubuntu@192.168.1.100
```

#### 3. Invalid IP Addresses

**Warning**: `Invalid IP address format for master-1.ansible_host: 192.168.1.256`

**Solution**:
```yaml
# Fix IP address in user_input.yml
control_plane_nodes:
  - name: "master-1"
    ansible_host: "192.168.1.100"  # Valid IP range: 0-255
```

#### 4. Missing Privilege Escalation

**Warning**: `Node 'master-1' uses non-root user 'ubuntu' but ansible_become is not enabled`

**Solution**:
```yaml
# Add privilege escalation configuration
control_plane_nodes:
  - name: "master-1"
    ansible_host: "192.168.1.100"
    ansible_user: "ubuntu"
    ansible_become: true           # Add this
    ansible_become_method: "sudo"  # Add this
    ansible_become_user: "root"    # Add this
```

### Debugging SSH Issues

#### Enable SSH Debug Output
```bash
# Test with verbose SSH output
ssh -vvv -i ~/.ssh/k8s_rsa ubuntu@192.168.1.100

# Check SSH daemon logs on remote host
sudo tail -f /var/log/auth.log  # Ubuntu/Debian
sudo tail -f /var/log/secure    # CentOS/RHEL
```

#### Check SSH Configuration
```bash
# Verify SSH server configuration (on remote host)
sudo sshd -T | grep -i pubkey
sudo sshd -T | grep -i password

# Check if SSH key is properly installed
cat ~/.ssh/authorized_keys  # On remote host
```

### Network Connectivity Issues

#### Test Basic Connectivity
```bash
# Ping test
ping -c 3 192.168.1.100

# Port connectivity test
nc -zv 192.168.1.100 22  # Test SSH port

# DNS resolution test
nslookup hostname
```

#### Firewall Issues
```bash
# Check firewall status (on remote host)
sudo ufw status        # Ubuntu
sudo firewall-cmd --list-all  # CentOS 7+

# Allow SSH if blocked
sudo ufw allow ssh     # Ubuntu
sudo firewall-cmd --permanent --add-service=ssh  # CentOS
```

## Integration with Deploy Script

### Automatic Integration

The validation is seamlessly integrated into `deploy_smartscaler.sh`:

```bash
# Validation runs first, then deployment
./deploy_smartscaler.sh

# Equivalent to:
python3 files/validate_config.py  # Validation
# If validation passes:
# - Prerequisites installation
# - Kubernetes setup
# - Application deployment
```

### Skipping Validation

```bash
# Skip validation (not recommended)
./deploy_smartscaler.sh --skip-validation

# Use only when:
# - Configuration is known to be correct
# - SSH connectivity issues are temporary
# - Testing deployment components independently
```

### Exit Codes

The validation script uses standard exit codes:

- **0**: Validation passed, ready for deployment
- **1**: Validation failed, deployment should not proceed

## Best Practices

### Configuration Management

1. **Version Control**: Store `user_input.yml` in version control
2. **Environment-Specific**: Maintain separate configs for dev/staging/prod
3. **Validation First**: Always validate before deployment
4. **Incremental Changes**: Validate after each configuration change

### SSH Key Management

1. **Dedicated Keys**: Use dedicated SSH keys for cluster deployment
2. **Key Rotation**: Regularly rotate SSH keys
3. **Secure Storage**: Store private keys securely
4. **Access Control**: Limit SSH key access to necessary personnel

### Privilege Escalation

1. **Least Privilege**: Use non-root users with sudo when possible
2. **Passwordless Sudo**: Configure for automation
3. **Audit Trail**: Monitor sudo usage
4. **Time-Limited**: Consider temporary access for deployments

### Validation Strategy

1. **Pre-Deployment**: Always validate before deployment
2. **CI/CD Integration**: Include validation in automated pipelines
3. **Regular Testing**: Periodically test SSH connectivity
4. **Documentation**: Document configuration requirements and patterns

## Advanced Configuration

### Custom Validation Rules

Extend validation for specific requirements:

```python
# Custom validation function
def validate_custom_requirements(config):
    """Add custom validation logic"""
    errors = []
    warnings = []
    
    # Example: Validate specific network ranges
    for node in config.get('control_plane_nodes', []):
        ip = ipaddress.ip_address(node['ansible_host'])
        if not ip.is_private:
            warnings.append(f"Node {node['name']} uses public IP")
    
    return errors, warnings
```

### Integration with External Tools

#### Terraform Integration
```bash
# Generate config from Terraform outputs
terraform output -json | python3 generate_config.py > user_input.yml

# Validate generated config
python3 files/validate_config.py
```

#### Ansible Inventory Integration
```bash
# Generate from existing Ansible inventory
ansible-inventory --list | python3 convert_inventory.py > user_input.yml

# Validate converted config
python3 files/validate_config.py
```

### Continuous Validation

#### Scheduled Validation
```bash
# Cron job for regular validation
0 6 * * * cd /path/to/smartscaler && python3 files/validate_config.py --quiet
```

#### Monitoring Integration
```bash
# Export validation metrics
python3 files/validate_config.py --metrics > validation_metrics.json

# Send to monitoring system
curl -X POST monitoring-endpoint -d @validation_metrics.json
```

This comprehensive validation system ensures reliable and predictable Smart Scaler deployments by catching configuration issues early in the process. 