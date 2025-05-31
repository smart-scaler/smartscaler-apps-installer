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
  - "Create NGC secrets"

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
  - name: "Create NGC secrets"
    ...
```

## Managing Vault Secrets

This project uses Ansible Vault to securely manage sensitive information like NGC API keys.

### Initial Setup

1. Create a vault password file (this file should NEVER be committed):
```bash
echo "your-secure-vault-password" > .vault_pass
chmod 600 .vault_pass
```

2. Create the vault file structure:
```bash
# Create the directory if it doesn't exist
mkdir -p group_vars/all

# Create an empty vault file
touch group_vars/all/vault.yml
```

3. Add your secrets to the vault file BEFORE encrypting:
```yaml
# NGC API credentials - NEVER store these in plain text
ngc_docker_api_key: "your-docker-api-key"
ngc_api_key: "your-ngc-api-key"

# Other sensitive information
other_secret: "sensitive-value"
```

4. Encrypt the vault file:
```bash
ansible-vault encrypt group_vars/all/vault.yml
```

### ⚠️ Important: Plain Text vs Encrypted Values

NEVER store sensitive information in plain text:

❌ INCORRECT (Plain text in version control):
```yaml
# DO NOT DO THIS
ngc_docker_api_key: "ngc-docker-key-123"
ngc_api_key: "ngc-api-key-456"
```

✅ CORRECT (Encrypted vault file):
1. First, create/edit the vault with:
```bash
ansible-vault edit group_vars/all/vault.yml
```

2. Add your secrets inside the encrypted file:
```yaml
ngc_docker_api_key: "ngc-docker-key-123"
ngc_api_key: "ngc-api-key-456"
```

3. Save and exit (the file remains encrypted)

### Managing NGC Credentials

To safely manage NGC credentials:

1. Edit the encrypted vault file:
```bash
ansible-vault edit group_vars/all/vault.yml
```

2. View the contents (if needed):
```bash
ansible-vault view group_vars/all/vault.yml
```

3. Verify the file is encrypted:
```bash
# Should show encrypted content
cat group_vars/all/vault.yml
```

### Security Best Practices

- Never commit unencrypted sensitive data
- Never store the vault password in version control
- Never share vault passwords through unsecured channels
- Keep your vault password secure
- Regularly rotate your NGC API keys
- Use different API keys for different environments
- Always verify files containing secrets are encrypted before committing
- Use `.gitignore` to prevent accidental commits:
```
# Add to .gitignore
.vault_pass
**/vault.yml.bak
**/vault.yml~
```

### Troubleshooting

If you see permission errors:
```bash
chmod 600 .vault_pass
chmod 600 group_vars/all/vault.yml
```

If you need to decrypt the file (be careful!):
```bash
ansible-vault decrypt group_vars/all/vault.yml
```

If you accidentally committed sensitive data:
1. Immediately revoke and rotate the exposed credentials
2. Remove the sensitive data from git history
3. Re-encrypt the vault file
4. Update all systems using the old credentials

## Installation

1. Clone the repository:
```bash
git clone https://github.com/smart-scaler/smartscaler-apps-installer.git
cd smartscaler-apps-installer
```

2. Set up vault secrets as described above

3. Run the installation:
```bash
ansible-playbook site.yml
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

[Add your license information here]
