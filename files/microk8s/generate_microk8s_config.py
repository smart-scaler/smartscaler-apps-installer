#!/usr/bin/env python3
import yaml
import os
from jinja2 import Template

def main():
    # Load user input
    with open('user_input.yml', 'r') as f:
        user_input = yaml.safe_load(f)

    # Load kubernetes deployment config
    k8s_config = user_input.get('kubernetes_deployment', {})
    microk8s_config = user_input.get('microk8s_deployment', {})

    # Generate inventory
    inventory_template = '''---
all:
  children:
    microk8s_cluster:
      hosts:
{% for node in control_plane_nodes %}
        {{ node['ansible_host'] }}:
          ansible_user: {{ node.get('ansible_user', default_ansible_user) }}
          ansible_become: {{ node.get('ansible_become', True) }}
          ansible_become_method: {{ node.get('ansible_become_method', 'sudo') }}
          ansible_become_user: {{ node.get('ansible_become_user', 'root') }}
          ansible_ssh_private_key_file: {{ ssh_key_path }}
          ansible_python_interpreter: /usr/bin/python3
          private_ip: {{ node['private_ip'] }}
          node_name: {{ node['name'] }}
          node_role: primary{% if loop.first %}-master{% endif %}
{% endfor %}
{% if worker_nodes %}
{% for node in worker_nodes %}
        {{ node['ansible_host'] }}:
          ansible_user: {{ node.get('ansible_user', default_ansible_user) }}
          ansible_become: {{ node.get('ansible_become', True) }}
          ansible_become_method: {{ node.get('ansible_become_method', 'sudo') }}
          ansible_become_user: {{ node.get('ansible_become_user', 'root') }}
          ansible_ssh_private_key_file: {{ ssh_key_path }}
          ansible_python_interpreter: /usr/bin/python3
          private_ip: {{ node['private_ip'] }}
          node_name: {{ node['name'] }}
          node_role: worker
{% endfor %}
{% endif %}
      vars:
        microk8s_channel: {{ microk8s_channel }}
        microk8s_addons: {{ microk8s_addons }}
        microk8s_additional_addons: {{ microk8s_additional_addons }}
        smart_scaler_namespace: {{ smart_scaler_namespace }}
        enable_nvidia_support: {{ enable_nvidia_support }}
        ansible_python_interpreter: /usr/bin/python3
'''

    # Get MicroK8s configuration
    microk8s_cfg = microk8s_config.get('microk8s_config', {})
    
    # Generate inventory
    template = Template(inventory_template)
    inventory_content = template.render(
        control_plane_nodes=k8s_config.get('control_plane_nodes', []),
        worker_nodes=k8s_config.get('worker_nodes', []),
        microk8s_channel=microk8s_config.get('microk8s_channel', 'latest/stable'),
        microk8s_addons=microk8s_cfg.get('addons', ['dns', 'storage', 'ingress']),
        microk8s_additional_addons=microk8s_cfg.get('additional_addons', []),
        smart_scaler_namespace=microk8s_cfg.get('cluster_setup', {}).get('smart_scaler_namespace', 'smart-scaler'),
        enable_nvidia_support=microk8s_cfg.get('container_runtime', {}).get('enable_nvidia_support', True),
        ssh_key_path=k8s_config.get('ssh_key_path', ''),
        default_ansible_user=k8s_config.get('default_ansible_user', 'root')
    )

    # Write inventory file
    with open('inventory/microk8s/inventory.yml', 'w') as f:
        f.write(inventory_content)

    print('✓ Generated inventory/microk8s/inventory.yml')

    # Generate cluster name and API endpoint
    cluster_name = "smart-scaler-microk8s-{}".format(k8s_config.get('control_plane_nodes', [{}])[0].get('name', 'cluster'))
    api_endpoint = k8s_config.get('control_plane_nodes', [{}])[0].get('ansible_host', '127.0.0.1')

    # Generate group_vars
    group_vars_template = '''---
# MicroK8s Group Variables
# Generated automatically for MicroK8s deployment

microk8s_channel: {microk8s_channel}
ansible_python_interpreter: /usr/bin/python3

# MicroK8s Add-ons Configuration
microk8s_addons: {microk8s_addons}
microk8s_additional_addons: {microk8s_additional_addons}

# MicroK8s Network Configuration
service_cidr: {service_cidr}
pod_cidr: {pod_cidr}
api_port: {api_port}

# MicroK8s API Configuration
api_endpoint: "{api_endpoint}"
kubeconfig: ~/.kube/config

# Cluster Configuration
cluster_context: "{cluster_name}"
cluster_name: "{cluster_name}"

# Smart Scaler Configuration
smart_scaler_namespace: {smart_scaler_namespace}
create_smart_scaler_namespace: {create_smart_scaler_namespace}

# Multi-node Configuration
enable_clustering: {enable_clustering}
join_timeout: {join_timeout}

# Security Configuration
enable_rbac: {enable_rbac}
enable_pod_security: {enable_pod_security}

# NVIDIA Support
enable_nvidia_support: {enable_nvidia_support}

# Storage Configuration
default_storage_class: {default_storage_class}

# High Availability Configuration
enable_ha: {enable_ha}
datastore: {datastore}
'''

    # Get configuration values with defaults
    network_config = microk8s_cfg.get('network', {})
    cluster_setup = microk8s_cfg.get('cluster_setup', {})
    security_config = microk8s_cfg.get('security', {})
    container_runtime = microk8s_cfg.get('container_runtime', {})
    storage_config = microk8s_cfg.get('storage', {})
    ha_config = microk8s_cfg.get('ha_config', {})

    # Use Python string formatting for group_vars
    group_vars_content = group_vars_template.format(
        microk8s_channel=microk8s_config.get('microk8s_channel', 'latest/stable'),
        microk8s_addons=microk8s_cfg.get('addons', ['dns', 'storage', 'ingress']),
        microk8s_additional_addons=microk8s_cfg.get('additional_addons', []),
        service_cidr=network_config.get('service_cidr', '10.152.183.0/24'),
        pod_cidr=network_config.get('pod_cidr', '10.1.0.0/16'),
        api_port=network_config.get('api_port', 16443),
        cluster_name=cluster_name,
        api_endpoint=api_endpoint,
        smart_scaler_namespace=cluster_setup.get('smart_scaler_namespace', 'smart-scaler'),
        create_smart_scaler_namespace=cluster_setup.get('create_smart_scaler_namespace', True),
        enable_clustering=cluster_setup.get('enable_clustering', True),
        join_timeout=cluster_setup.get('join_timeout', 300),
        enable_rbac=security_config.get('enable_rbac', True),
        enable_pod_security=security_config.get('enable_pod_security', True),
        enable_nvidia_support=container_runtime.get('enable_nvidia_support', True),
        default_storage_class=storage_config.get('default_storage_class', 'microk8s-hostpath'),
        enable_ha=ha_config.get('enable_ha', False),
        datastore=ha_config.get('datastore', 'dqlite')
    )

    # Write group_vars file
    os.makedirs('inventory/microk8s/group_vars', exist_ok=True)
    with open('inventory/microk8s/group_vars/all.yml', 'w') as f:
        f.write(group_vars_content)

    print('✓ Generated inventory/microk8s/group_vars/all.yml')

    # Validate configuration
    print('\n🔍 Validating MicroK8s Configuration:')
    print(f'  - MicroK8s Channel: {microk8s_config.get("microk8s_channel", "latest/stable")}')
    print(f'  - Essential Add-ons: {microk8s_cfg.get("addons", ["dns", "storage", "ingress"])}')
    print(f'  - Additional Add-ons: {microk8s_cfg.get("additional_addons", [])}')
    print(f'  - Service CIDR: {network_config.get("service_cidr", "10.152.183.0/24")}')
    print(f'  - Pod CIDR: {network_config.get("pod_cidr", "10.1.0.0/16")}')
    print(f'  - API Port: {network_config.get("api_port", 16443)}')
    print(f'  - NVIDIA Support: {container_runtime.get("enable_nvidia_support", True)}')

    # Validate multi-node configuration
    num_control_plane = len(k8s_config.get('control_plane_nodes', []))
    num_workers = len(k8s_config.get('worker_nodes', []))
    total_nodes = num_control_plane + num_workers
    
    if total_nodes > 1:
        print(f'\n🔧 Multi-Node Configuration Detected ({total_nodes} total nodes)')
        print(f'  - Control Plane Nodes: {num_control_plane}')
        print(f'  - Worker Nodes: {num_workers}')
        if cluster_setup.get('enable_clustering', True):
            print('✓ Clustering enabled for multi-node setup')
        else:
            print('⚠️  WARNING: Clustering is disabled but you have multiple nodes.')
            print('   Consider enabling enable_clustering: true in microk8s_config.cluster_setup')
            
        if num_control_plane >= 3 and ha_config.get('enable_ha', False):
            print('✓ High Availability enabled for multi-master setup')
        elif num_control_plane >= 3:
            print('⚠️  WARNING: You have 3+ control plane nodes but HA is not enabled.')
            print('   Consider enabling enable_ha: true in microk8s_config.ha_config')
    elif total_nodes == 1:
        print('\n🔧 Single Node Configuration')
    else:
        print('\n❌ ERROR: No nodes configured!')
        exit(1)

    print('\nSuccessfully generated MicroK8s configuration files.')

    # Generate cluster name
    print(f'\n🔧 Cluster Configuration:')
    print(f'  - Cluster Name: {cluster_name}')
    print(f'  - Cluster Context: {cluster_name}')
    print(f'  - API Endpoint: {api_endpoint}:{network_config.get("api_port", 16443)}')

    # Print nodes for verification
    print('\nControl Plane Nodes:')
    for node in k8s_config.get('control_plane_nodes', []):
        user = node.get('ansible_user', k8s_config.get('default_ansible_user', 'root'))
        print(f'  - {node["name"]}: Public IP: {node["ansible_host"]}, Private IP: {node["private_ip"]} (user: {user})')

    if k8s_config.get('worker_nodes'):
        print('\nWorker Nodes:')
        for node in k8s_config['worker_nodes']:
            user = node.get('ansible_user', k8s_config.get('default_ansible_user', 'root'))
            print(f'  - {node["name"]}: Public IP: {node["ansible_host"]}, Private IP: {node["private_ip"]} (user: {user})')

    # Print complete generated inventory
    print('\n' + '='*80)
    print('Complete Generated MicroK8s Inventory File (inventory/microk8s/inventory.yml):')
    print('='*80)
    with open('inventory/microk8s/inventory.yml', 'r') as f:
        print(f.read())
    print('='*80)

    # Print generated group_vars for verification
    print('\n' + '='*80)
    print('Generated MicroK8s Group Variables (inventory/microk8s/group_vars/all.yml):')
    print('='*80)
    with open('inventory/microk8s/group_vars/all.yml', 'r') as f:
        print(f.read())
    print('='*80)

if __name__ == "__main__":
    main()
