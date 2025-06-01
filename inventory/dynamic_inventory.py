#!/usr/bin/env python3

import json
import os
import sys
import yaml

def load_user_input():
    """Load user_input.yml file"""
    user_input_paths = [
        os.path.join(os.path.dirname(__file__), '..', 'vars', 'user_input.yml'),
        os.path.join(os.path.dirname(__file__), '..', 'user_input.yml')
    ]
    
    for path in user_input_paths:
        if os.path.exists(path):
            with open(path, 'r') as f:
                return yaml.safe_load(f)
    return {}

def get_inventory():
    """Generate the inventory"""
    user_input = load_user_input()
    kubernetes_deployment = user_input.get('kubernetes_deployment', {})
    use_remote = kubernetes_deployment.get('kubeconfig', {}).get('use_remote', False)
    
    inventory = {
        '_meta': {
            'hostvars': {}
        },
        'all': {
            'hosts': [],
            'children': ['kubernetes']
        },
        'kubernetes': {
            'hosts': [],
            'children': ['kubernetes_master']
        },
        'kubernetes_master': {
            'hosts': []
        }
    }
    
    if use_remote:
        control_plane_nodes = kubernetes_deployment.get('control_plane_nodes', [])
        if control_plane_nodes:
            master_host = control_plane_nodes[0].get('ansible_host')
            if master_host:
                inventory['kubernetes_master']['hosts'].append('master')
                inventory['_meta']['hostvars']['master'] = {
                    'ansible_host': master_host,
                    'ansible_user': kubernetes_deployment.get('default_ansible_user'),
                    'ansible_ssh_private_key_file': kubernetes_deployment.get('ssh_key_path')
                }
    else:
        inventory['kubernetes_master']['hosts'].append('localhost')
        inventory['_meta']['hostvars']['localhost'] = {
            'ansible_connection': 'local'
        }
    
    return inventory

def main():
    """Main function"""
    if len(sys.argv) == 2 and sys.argv[1] == '--list':
        inventory = get_inventory()
        print(json.dumps(inventory, indent=2))
    elif len(sys.argv) == 3 and sys.argv[1] == '--host':
        # We've already handled host vars in the --list
        print(json.dumps({}))
    else:
        print("Usage: %s --list or --host <hostname>" % sys.argv[0])
        sys.exit(1)

if __name__ == '__main__':
    main() 