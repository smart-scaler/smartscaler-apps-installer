# Kubernetes Firewall Configuration

This document describes the firewall configuration for Kubernetes cluster nodes implemented in our Ansible automation.

## Features

- Automatic firewall rules management
- Node-specific port configurations
- Control plane and worker node differentiation
- Secure communication channels
- Automated rule validation

## Configuration

### Firewall Settings in Configuration

The firewall configuration is managed through your `user_input.yml`:

```yaml
kubernetes_deployment:
  firewall:
    enabled: true  # Set to false to disable
```

### What's Covered

1. **Control Plane Ports**
   - 6443: Kubernetes API server
   - 2379-2380: etcd server client API
   - 10250: Kubelet API
   - 10259: kube-scheduler
   - 10257: kube-controller-manager

2. **Worker Node Ports**
   - 10250: Kubelet API
   - 30000-32767: NodePort Services
   - 8080: Container Registry
   - 3476: NVIDIA Container Runtime (when enabled)

3. **Common Ports**
   - 179: Calico BGP (if using Calico)
   - 4789: Calico VXLAN
   - 5473: Calico Typha
   - 9099: Calico health checks

4. **Additional Services**
   - Custom port ranges for specific services
   - Load balancer configurations
   - Metrics server ports

## Implementation Details

### Port Configuration

1. **Control Plane Communication**
   ```yaml
   - port: 6443
     protocol: tcp
     description: "Kubernetes API Server"
   ```

2. **Worker Node Communication**
   ```yaml
   - port_range: "30000-32767"
     protocol: tcp
     description: "NodePort Services"
   ```

### Security Features

1. **IP-based Restrictions**
   - Node-to-node communication
   - External access control
   - Service-specific IP ranges

2. **Protocol Management**
   - TCP/UDP protocol handling
   - ICMP rules
   - Custom protocol support

## Usage

### Enabling Firewall Configuration

1. Enable firewall management in your configuration:
   ```yaml
   kubernetes_deployment:
     firewall:
       enabled: true
   ```

2. Run the Ansible playbook:
   ```bash
   ansible-playbook -i inventory/your-inventory main.yml
   ```

### Validation

To verify the firewall configuration:

1. Check firewall status:
   ```bash
   sudo ufw status verbose
   ```

2. Verify port accessibility:
   ```bash
   nc -zv [NODE_IP] [PORT]
   ```

3. Test cluster communication:
   ```bash
   kubectl get nodes
   ```

## Troubleshooting

Common issues and solutions:

1. **Node Communication Issues**
   - Verify firewall rules are properly applied
   - Check node IP configurations
   - Validate port accessibility

2. **Service Access Problems**
   - Check NodePort range configuration
   - Verify service port mappings
   - Review firewall logs

3. **External Access Issues**
   - Validate LoadBalancer configurations
   - Check ingress controller settings
   - Review external IP allowances

## Disabling Firewall Management

To disable firewall management:

1. Set `enabled: false` in your configuration:
   ```yaml
   kubernetes_deployment:
     firewall:
       enabled: false
   ```

2. Run the playbook again to apply changes

Note: This won't remove existing firewall rules but will skip firewall management tasks in future runs.

## Custom Port Configuration

To add custom port rules:

```yaml
kubernetes_deployment:
  firewall:
    enabled: true
    custom_rules:
      - port: 8443
        protocol: tcp
        description: "Custom HTTPS"
      - port_range: "9000-9100"
        protocol: tcp
        description: "Custom Service Range"
```

## Best Practices

1. **Security**
   - Regularly review and audit firewall rules
   - Implement least-privilege access
   - Document all custom configurations

2. **Maintenance**
   - Keep rule sets minimal and necessary
   - Regular validation of configurations
   - Maintain backup of working configurations

3. **Monitoring**
   - Log firewall activities
   - Monitor blocked connections
   - Track rule effectiveness 