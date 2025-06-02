#!/usr/bin/env python3
"""
Smart Scaler Configuration Validator
Validates user_input.yml for proper node configuration and privilege escalation settings.
"""

import yaml
import sys
import os
from pathlib import Path
import ipaddress
import subprocess

def print_status(message):
    print(f"\033[34m[INFO]\033[0m {message}")

def print_success(message):
    print(f"\033[32m[SUCCESS]\033[0m {message}")

def print_error(message):
    print(f"\033[31m[ERROR]\033[0m {message}")

def print_warning(message):
    print(f"\033[33m[WARNING]\033[0m {message}")

def validate_yaml_syntax(config_file):
    """Validate YAML syntax"""
    try:
        with open(config_file, 'r') as f:
            yaml.safe_load(f)
        print_success("YAML syntax is valid")
        return True
    except yaml.YAMLError as e:
        print_error(f"YAML syntax error: {e}")
        return False
    except FileNotFoundError:
        print_error(f"Configuration file not found: {config_file}")
        return False

def validate_ip_address(ip_str, field_name):
    """Validate IP address format"""
    try:
        ipaddress.ip_address(ip_str)
        return True
    except ValueError:
        print_warning(f"Invalid IP address format for {field_name}: {ip_str}")
        return False

def validate_ssh_key(ssh_key_path):
    """Validate SSH key exists and has correct permissions"""
    key_path = Path(ssh_key_path).expanduser()
    
    if not key_path.exists():
        print_error(f"SSH private key not found: {key_path}")
        return False
    
    # Check permissions (should be 600)
    permissions = oct(key_path.stat().st_mode)[-3:]
    if permissions != '600':
        print_warning(f"SSH key permissions are {permissions}, should be 600: {key_path}")
    
    # Check if public key exists
    pub_key_path = Path(str(key_path) + '.pub')
    if not pub_key_path.exists():
        print_warning(f"SSH public key not found: {pub_key_path}")
        return False
    
    print_success(f"SSH key configuration valid: {key_path}")
    return True

def validate_node_config(node, node_type, default_user):
    """Validate individual node configuration"""
    errors = []
    warnings = []
    
    # Required fields
    if 'name' not in node:
        errors.append("Missing required field: 'name'")
    
    if 'ansible_host' not in node:
        errors.append("Missing required field: 'ansible_host'")
    else:
        # Validate IP address format
        if not validate_ip_address(node['ansible_host'], f"{node.get('name', 'unnamed')}.ansible_host"):
            warnings.append(f"Consider using valid IP address for ansible_host: {node['ansible_host']}")
    
    # Validate private_ip if present
    if 'private_ip' in node:
        if not validate_ip_address(node['private_ip'], f"{node.get('name', 'unnamed')}.private_ip"):
            warnings.append(f"Invalid private_ip format: {node['private_ip']}")
    
    # Check user configuration
    user = node.get('ansible_user', default_user)
    if not user:
        errors.append("No ansible_user specified and no default_ansible_user set")
    
    # Validate privilege escalation configuration
    if user != 'root':
        if not node.get('ansible_become'):
            warnings.append(f"Node '{node.get('name')}' uses non-root user '{user}' but ansible_become is not enabled")
        else:
            if not node.get('ansible_become_method'):
                warnings.append(f"Node '{node.get('name')}' has ansible_become=true but no ansible_become_method specified")
            
            if not node.get('ansible_become_user'):
                warnings.append(f"Node '{node.get('name')}' has ansible_become=true but no ansible_become_user specified")
    
    return errors, warnings

def test_ssh_connectivity(node, ssh_key_path, default_user):
    """Test SSH connectivity to a node"""
    host = node['ansible_host']
    user = node.get('ansible_user', default_user)
    name = node.get('name', 'unnamed')
    
    key_path = Path(ssh_key_path).expanduser()
    
    # Test SSH connectivity
    cmd = [
        'ssh', '-i', str(key_path),
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'BatchMode=yes',
        '-o', 'ConnectTimeout=10',
        f'{user}@{host}',
        'echo "SSH connection successful"'
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, timeout=15)
        if result.returncode == 0:
            print_success(f"SSH connectivity successful: {name} ({user}@{host})")
            
            # Test sudo if privilege escalation is configured
            if node.get('ansible_become') and user != 'root':
                sudo_cmd = [
                    'ssh', '-i', str(key_path),
                    '-o', 'StrictHostKeyChecking=no',
                    '-o', 'BatchMode=yes',
                    '-o', 'ConnectTimeout=10',
                    f'{user}@{host}',
                    'sudo whoami'
                ]
                
                try:
                    sudo_result = subprocess.run(sudo_cmd, capture_output=True, timeout=15)
                    if sudo_result.returncode == 0:
                        print_success(f"Sudo privilege escalation successful: {name}")
                    else:
                        print_error(f"Sudo privilege escalation failed: {name}")
                        print_error(f"  Error: {sudo_result.stderr.decode().strip()}")
                        return False
                except subprocess.TimeoutExpired:
                    print_error(f"Sudo test timeout: {name}")
                    return False
            
            return True
        else:
            print_error(f"SSH connectivity failed: {name} ({user}@{host})")
            print_error(f"  Error: {result.stderr.decode().strip()}")
            return False
            
    except subprocess.TimeoutExpired:
        print_error(f"SSH connection timeout: {name} ({user}@{host})")
        return False
    except Exception as e:
        print_error(f"SSH test error for {name}: {e}")
        return False

def main():
    print_status("Smart Scaler Configuration Validator")
    print_status("=" * 50)
    
    config_file = 'user_input.yml'
    
    # Validate YAML syntax
    if not validate_yaml_syntax(config_file):
        sys.exit(1)
    
    # Load configuration
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f)
    
    k8s_config = config.get('kubernetes_deployment', {})
    
    if not k8s_config.get('enabled'):
        print_warning("Kubernetes deployment is disabled")
        return
    
    print_status("\nValidating Kubernetes deployment configuration...")
    
    # Get configuration values
    ssh_key_path = k8s_config.get('ssh_key_path', '~/.ssh/k8s_rsa')
    default_user = k8s_config.get('default_ansible_user', 'root')
    control_plane_nodes = k8s_config.get('control_plane_nodes', [])
    worker_nodes = k8s_config.get('worker_nodes', [])
    
    all_errors = []
    all_warnings = []
    
    # Validate SSH key
    if not validate_ssh_key(ssh_key_path):
        all_errors.append("SSH key validation failed")
    
    # Validate control plane nodes
    print_status(f"\nValidating {len(control_plane_nodes)} control plane node(s)...")
    for i, node in enumerate(control_plane_nodes):
        print_status(f"Validating control plane node {i+1}: {node.get('name', 'unnamed')}")
        errors, warnings = validate_node_config(node, 'control_plane', default_user)
        all_errors.extend([f"Control plane node {i+1}: {e}" for e in errors])
        all_warnings.extend([f"Control plane node {i+1}: {w}" for w in warnings])
    
    # Validate worker nodes
    if worker_nodes:
        print_status(f"\nValidating {len(worker_nodes)} worker node(s)...")
        for i, node in enumerate(worker_nodes):
            print_status(f"Validating worker node {i+1}: {node.get('name', 'unnamed')}")
            errors, warnings = validate_node_config(node, 'worker', default_user)
            all_errors.extend([f"Worker node {i+1}: {e}" for e in errors])
            all_warnings.extend([f"Worker node {i+1}: {w}" for w in warnings])
    
    # Test SSH connectivity (optional)
    test_connectivity = input("\nTest SSH connectivity to nodes? [y/N]: ").lower().startswith('y')
    
    if test_connectivity:
        print_status("\nTesting SSH connectivity...")
        ssh_failures = []
        
        for node in control_plane_nodes + worker_nodes:
            if not test_ssh_connectivity(node, ssh_key_path, default_user):
                ssh_failures.append(node.get('name', 'unnamed'))
        
        if ssh_failures:
            all_errors.extend([f"SSH connectivity failed for: {', '.join(ssh_failures)}"])
    
    # Report results
    print_status("\n" + "=" * 50)
    print_status("VALIDATION RESULTS")
    print_status("=" * 50)
    
    if all_warnings:
        print_warning(f"Found {len(all_warnings)} warning(s):")
        for warning in all_warnings:
            print_warning(f"  • {warning}")
        print()
    
    if all_errors:
        print_error(f"Found {len(all_errors)} error(s):")
        for error in all_errors:
            print_error(f"  • {error}")
        print()
        print_error("Please fix the errors before proceeding with deployment.")
        sys.exit(1)
    else:
        print_success("Configuration validation passed!")
        print_success("Ready for deployment.")
        
        # Show deployment command
        print_status("\nNext steps:")
        print("1. Run deployment: ./deploy_smartscaler.sh")
        print("2. Or run individual components:")
        print("   - Prerequisites only: ./deploy_smartscaler.sh --skip-k8s --skip-apps")
        print("   - Kubernetes only: ./deploy_smartscaler.sh --skip-prereq --skip-apps")
        print("   - Applications only: ./deploy_smartscaler.sh --skip-prereq --skip-k8s")

if __name__ == "__main__":
    main() 