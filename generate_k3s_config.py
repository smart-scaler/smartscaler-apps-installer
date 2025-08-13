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
    k3s_config = user_input.get('k3s_deployment', {})

    # Generate inventory
    inventory_template = '''---
k3s_cluster:
  children:
    server:
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
{% endfor %}
{% if worker_nodes %}
    agent:
      hosts:
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
{% endfor %}
{% endif %}

  vars:
    k3s_version: {{ k3s_version }}
    service_cidr: {{ service_cidr }}
    cluster_cidr: {{ cluster_cidr }}
    cluster_dns: {{ cluster_dns }}
    cni: {{ cni }}
    use_external_database: {{ use_external_database }}
    ansible_python_interpreter: /usr/bin/python3
'''

    # Generate inventory
    template = Template(inventory_template)
    inventory_content = template.render(
        control_plane_nodes=k8s_config.get('control_plane_nodes', []),
        worker_nodes=k8s_config.get('worker_nodes', []),
        k3s_version=k3s_config.get('k3s_version', 'v1.28.0+k3s1'),
        service_cidr=k3s_config.get('k3s_config', {}).get('service_cidr', '10.43.0.0/16'),
        cluster_cidr=k3s_config.get('k3s_config', {}).get('cluster_cidr', '10.42.0.0/16'),
        cluster_dns=k3s_config.get('k3s_config', {}).get('cluster_dns', '10.43.0.10'),
        cni=k3s_config.get('k3s_config', {}).get('cni', 'flannel'),
        use_external_database=k3s_config.get('k3s_config', {}).get('use_external_database', False),
        ssh_key_path=k8s_config.get('ssh_key_path', ''),
        default_ansible_user=k8s_config.get('default_ansible_user', 'root')
    )

    # Write inventory file
    with open('inventory/k3s/inventory.yml', 'w') as f:
        f.write(inventory_content)

    print('✓ Generated inventory/k3s/inventory.yml')

    # Generate cluster name and API endpoint
    cluster_name = "smart-scaler-k3s-{}".format(k8s_config.get('control_plane_nodes', [{}])[0].get('name', 'cluster'))
    api_endpoint = k8s_config.get('control_plane_nodes', [{}])[0].get('ansible_host', '127.0.0.1')

    # Generate group_vars
    group_vars_template = '''---
# K3s Group Variables
# Generated automatically for K3s deployment

k3s_version: {k3s_version}
service_cidr: {service_cidr}
cluster_cidr: {cluster_cidr}
cluster_dns: {cluster_dns}
cni: {cni}
use_external_database: {use_external_database}
ansible_python_interpreter: /usr/bin/python3
disable_firewalld: true
disable_swap: true

# K3s API Configuration
api_endpoint: "{api_endpoint}"
api_port: 6443
kubeconfig: ~/.kube/config.new

# Cluster Configuration
cluster_context: "{cluster_name}"
cluster_name: "{cluster_name}"

# Node Configuration
extra_server_args: "--node-label node.kubernetes.io/role=control-plane --node-label node-type=master --node-label cluster={cluster_name}"
extra_agent_args: "--node-label node.kubernetes.io/role=worker --node-label node-type=worker --node-label cluster={cluster_name}"

# Additional Configuration
user_kubectl: true
'''

    # Use Python string formatting for group_vars
    group_vars_content = group_vars_template.format(
        k3s_version=k3s_config.get('k3s_version', 'v1.28.0+k3s1'),
        service_cidr=k3s_config.get('k3s_config', {}).get('service_cidr', '10.43.0.0/16'),
        cluster_cidr=k3s_config.get('k3s_config', {}).get('cluster_cidr', '10.42.0.0/16'),
        cluster_dns=k3s_config.get('k3s_config', {}).get('cluster_dns', '10.43.0.10'),
        cni=k3s_config.get('k3s_config', {}).get('cni', 'flannel'),
        use_external_database=k3s_config.get('k3s_config', {}).get('use_external_database', False),
        cluster_name=cluster_name,
        api_endpoint=api_endpoint
    )

    # Write group_vars file
    os.makedirs('inventory/k3s/group_vars', exist_ok=True)
    with open('inventory/k3s/group_vars/all.yml', 'w') as f:
        f.write(group_vars_content)

    print('✓ Generated inventory/k3s/group_vars/all.yml')

    # Validate configuration
    print('\n🔍 Validating K3s Configuration:')
    print(f'  - K3s Version: {k3s_config.get("k3s_version", "v1.28.0+k3s1")}')
    print(f'  - CNI Plugin: {k3s_config.get("k3s_config", {}).get("cni", "flannel")}')
    print(f'  - Service CIDR: {k3s_config.get("k3s_config", {}).get("service_cidr", "10.43.0.0/16")}')
    print(f'  - Cluster CIDR: {k3s_config.get("k3s_config", {}).get("cluster_cidr", "10.42.0.0/16")}')
    print(f'  - External Database: {k3s_config.get("k3s_config", {}).get("use_external_database", False)}')

    # Validate multi-master configuration
    num_control_plane = len(k8s_config.get('control_plane_nodes', []))
    if num_control_plane > 1:
        print(f'\n🔧 Multi-Master Configuration Detected ({num_control_plane} control plane nodes)')
        if not k3s_config.get('k3s_config', {}).get('use_external_database', False):
            print('⚠️  WARNING: External database is disabled but you have multiple control plane nodes.')
            print('   This configuration may cause issues. Consider enabling use_external_database: true')
        else:
            print('✓ External database enabled for multi-master setup')
    elif num_control_plane == 1:
        print('\n🔧 Single Master Configuration')
    else:
        print('\n❌ ERROR: No control plane nodes configured!')
        exit(1)

    print('\nSuccessfully generated K3s configuration files.')

    # Generate cluster name
    print(f'\n🔧 Cluster Configuration:')
    print(f'  - Cluster Name: {cluster_name}')
    print(f'  - Cluster Context: {cluster_name}')
    print(f'  - API Endpoint: {api_endpoint}')

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
    print('Complete Generated K3s Inventory File (inventory/k3s/inventory.yml):')
    print('='*80)
    with open('inventory/k3s/inventory.yml', 'r') as f:
        print(f.read())
    print('='*80)

    # Print generated group_vars for verification
    print('\n' + '='*80)
    print('Generated K3s Group Variables (inventory/k3s/group_vars/all.yml):')
    print('='*80)
    with open('inventory/k3s/group_vars/all.yml', 'r') as f:
        print(f.read())
    print('='*80)

if __name__ == "__main__":
    main()
