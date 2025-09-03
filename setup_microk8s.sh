#!/bin/bash
set -e

# Simple MicroK8s Setup Script
# Most logic moved to Ansible for better maintainability

echo "🚀 MicroK8s Deployment Setup"
echo "============================"

# Basic requirement checks
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 is required. Please install it first."
    exit 1
fi

if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Ansible is required. Please install it first."
    exit 1
fi

# Check if MicroK8s deployment is enabled
MICROK8S_ENABLED=$(python3 -c "
import yaml
try:
    with open('user_input.yml', 'r') as f:
        data = yaml.safe_load(f)
    print(data.get('microk8s_deployment', {}).get('enabled', False))
except Exception as e:
    print('false')
" 2>/dev/null)

if [ "$MICROK8S_ENABLED" != "True" ]; then
    echo "❌ MicroK8s deployment is disabled in user_input.yml"
    echo "   Set microk8s_deployment.enabled: true to continue"
    exit 1
fi

echo "✅ MicroK8s deployment is enabled"
echo "🎯 Running Ansible setup playbook..."

# Run the Ansible setup playbook that handles everything
ansible-playbook setup.yml -e deployment_type=microk8s

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ MicroK8s setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Review configuration: inventory/microk8s/"
    echo "  2. Deploy cluster: ansible-playbook microk8s.yml"
    echo ""
else
    echo "❌ Setup failed. Check the output above for details."
    exit 1
fi
