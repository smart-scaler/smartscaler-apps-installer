#!/usr/bin/env python3
import yaml
import subprocess
import os
import sys

def test_ssh(host, user, key_path):
    expanded_key_path = os.path.expanduser(key_path)
    if not os.path.exists(expanded_key_path):
        print(f'Error: SSH key file not found at {expanded_key_path}', file=sys.stderr)
        return False
    
    cmd = f'ssh -i {expanded_key_path} -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 {user}@{host} "echo SSH connection successful"'
    try:
        subprocess.run(cmd, shell=True, check=True, capture_output=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f'SSH connection failed: {str(e)}', file=sys.stderr)
        return False

try:
    with open('user_input.yml', 'r') as f:
        data = yaml.safe_load(f)

    if 'kubernetes_deployment' not in data:
        print('Error: kubernetes_deployment section not found in user_input.yml', file=sys.stderr)
        print('MicroK8s deployment requires the kubernetes_deployment section for node configuration', file=sys.stderr)
        sys.exit(1)

    if 'microk8s_deployment' not in data:
        print('Error: microk8s_deployment section not found in user_input.yml', file=sys.stderr)
        sys.exit(1)

    if not data['microk8s_deployment'].get('enabled', False):
        print('MicroK8s deployment is disabled in user_input.yml', file=sys.stderr)
        sys.exit(1)

    kube_config = data['kubernetes_deployment']
    nodes = kube_config['control_plane_nodes']
    if 'worker_nodes' in kube_config:
        nodes.extend(kube_config['worker_nodes'])

    print(f'Testing SSH connectivity for MicroK8s deployment to {len(nodes)} nodes...')

    failed_nodes = []
    for node in nodes:
        user = node.get('ansible_user', kube_config['default_ansible_user'])
        print(f'\nTesting connection to {node["name"]} ({node["ansible_host"]}) as user {user}...')
        if not test_ssh(node['ansible_host'], user, kube_config['ssh_key_path']):
            failed_nodes.append(f"{node['name']} ({user}@{node['ansible_host']})")

    if failed_nodes:
        print(f'\nFailed to connect to nodes: {", ".join(failed_nodes)}', file=sys.stderr)
        print('\nPlease check:', file=sys.stderr)
        print('1. SSH key permissions (should be 600)', file=sys.stderr)
        print('2. SSH key path is correct', file=sys.stderr)
        print('3. Target nodes are accessible', file=sys.stderr)
        print('4. User accounts exist on target nodes', file=sys.stderr)
        print('5. SSH service is running on target nodes', file=sys.stderr)
        sys.exit(1)
    else:
        print('\n✓ Successfully connected to all nodes for MicroK8s deployment!')

except FileNotFoundError:
    print('Error: user_input.yml file not found', file=sys.stderr)
    sys.exit(1)
except yaml.YAMLError as e:
    print(f'Error parsing YAML: {str(e)}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'Error: {str(e)}', file=sys.stderr)
    sys.exit(1)
