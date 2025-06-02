# Kubernetes Firewall Configuration

This document describes the comprehensive firewall configuration for Kubernetes cluster nodes implemented in the Smart Scaler platform deployment using our Ansible automation.

## Features

- Automatic firewall rules management for all Kubernetes components
- Node-specific port configurations for control plane and worker nodes
- Smart Scaler application port management
- Secure communication channels for all services
- Automated rule validation and testing
- Support for custom application ports
- Integration with Smart Scaler monitoring and AI/ML components

## Prerequisites

- Ubuntu-based nodes with firewall capabilities
- Kubernetes cluster deployed using our Ansible playbooks
- Proper SSH access to all cluster nodes
- UFW (Uncomplicated Firewall) available on target systems
- Administrative privileges on cluster nodes
- Network connectivity between cluster nodes

## Configuration

### Firewall Settings in Configuration

The firewall configuration is managed through your `user_input.yml`:

```yaml
kubernetes_deployment:
  firewall:
    enabled: true                             # Enable automatic firewall management
    allow_additional_ports: []                # Additional custom ports to open
```

### Enhanced Configuration Options

The enhanced firewall management provides comprehensive control:

```yaml
firewall:
  enabled: true                             # Master switch for firewall management
  allow_additional_ports:                   # Custom ports for applications
    - "8080"                               # Custom HTTP port
    - "9090"                               # Prometheus metrics
    - "3000"                               # Grafana dashboard
    - "6379"                               # Redis (Smart Scaler)
    - "4321"                               # Custom application port
    - "8265"                               # Ray dashboard (Smart Scaler)
    - "9900"                               # Smart Scaler inference
```

## What's Covered

### 1. Control Plane Ports

Essential Kubernetes control plane communication ports:

| Port | Service | Description |
|------|---------|-------------|
| 6443 | Kubernetes API server | Main API endpoint for all cluster operations |
| 2379-2380 | etcd server client API | Distributed key-value store |
| 10250 | Kubelet API | Node agent communication |
| 10259 | kube-scheduler | Pod scheduling service |
| 10257 | kube-controller-manager | Cluster control loops |

### 2. Worker Node Ports

Worker node communication and service ports:

| Port Range | Service | Description |
|------------|---------|-------------|
| 10250 | Kubelet API | Node agent on worker nodes |
| 30000-32767 | NodePort Services | External service access |
| 8080 | Container Registry | Local registry access |
| 3476 | NVIDIA Container Runtime | GPU container management |

### 3. CNI Network Ports (Calico)

Container Network Interface communication:

| Port | Service | Description |
|------|---------|-------------|
| 179 | Calico BGP | Border Gateway Protocol routing |
| 4789 | Calico VXLAN | Virtual extensible LAN |
| 5473 | Calico Typha | Cluster datastore proxy |
| 9099 | Calico health checks | Component health monitoring |

### 4. Smart Scaler Application Ports

Smart Scaler platform specific ports:

| Port | Service | Description |
|------|---------|-------------|
| 9090 | Prometheus | Metrics collection and monitoring |
| 3000 | Grafana | Visualization and dashboards |
| 8000 | NIM Services | AI model inference endpoints |
| 6379 | Redis | Smart Scaler state management |
| 4321 | Custom Apps | Smart Scaler application ports |
| 8265 | Ray Dashboard | Distributed computing dashboard |
| 9900 | Smart Scaler Inference | Main inference service |

### 5. Load Balancer and Ingress Ports

External access and load balancing:

| Port | Service | Description |
|------|---------|-------------|
| 80 | HTTP Ingress | Web traffic ingress |
| 443 | HTTPS Ingress | Secure web traffic |
| 8080 | Alternative HTTP | Custom web services |

## Implementation Details

### Automated Port Configuration

The automation intelligently configures ports based on enabled components:

```yaml
# Control plane ports (always enabled)
control_plane_ports:
  - { port: 6443, protocol: tcp, description: "Kubernetes API Server" }
  - { port: 2379, protocol: tcp, description: "etcd client API" }
  - { port: 2380, protocol: tcp, description: "etcd peer API" }
  - { port: 10250, protocol: tcp, description: "Kubelet API" }
  - { port: 10259, protocol: tcp, description: "kube-scheduler" }
  - { port: 10257, protocol: tcp, description: "kube-controller-manager" }

# Worker node ports (when worker nodes present)
worker_node_ports:
  - { port: 10250, protocol: tcp, description: "Kubelet API" }
  - { port_range: "30000:32767", protocol: tcp, description: "NodePort Services" }

# Smart Scaler ports (when components enabled)
smart_scaler_ports:
  - { port: 9090, protocol: tcp, description: "Prometheus" }
  - { port: 3000, protocol: tcp, description: "Grafana" }
  - { port: 8000, protocol: tcp, description: "NIM Services" }
  - { port: 6379, protocol: tcp, description: "Redis/Smart Scaler" }
  - { port: 8265, protocol: tcp, description: "Ray Dashboard" }
  - { port: 9900, protocol: tcp, description: "Smart Scaler Inference" }
```

### Security Features

Enhanced security implementation:

1. **Default Deny Policy**: All incoming traffic is denied by default
2. **Minimal Port Opening**: Only required ports are opened
3. **Component-Based Rules**: Ports opened only when components are enabled
4. **IP-based Restrictions**: Support for source IP restrictions
5. **Protocol-Specific Rules**: TCP/UDP/ICMP handling

### Advanced Firewall Rules

```yaml
# Advanced firewall configuration (automatically applied)
advanced_rules:
  # SSH access (secure)
  - { port: 22, protocol: tcp, source: "cluster_networks", description: "SSH access" }
  
  # DNS resolution
  - { port: 53, protocol: udp, description: "DNS resolution" }
  - { port: 53, protocol: tcp, description: "DNS over TCP" }
  
  # NTP synchronization
  - { port: 123, protocol: udp, description: "NTP time sync" }
  
  # ICMP for connectivity testing
  - { protocol: icmp, description: "ICMP ping and diagnostics" }
```

## Smart Scaler Integration

### Component-Specific Port Management

The firewall automatically adapts to enabled Smart Scaler components:

#### GPU Operator Ports
```yaml
# When GPU Operator is enabled
gpu_operator_ports:
  - { port: 3476, protocol: tcp, description: "NVIDIA Container Runtime" }
  - { port: 9100, protocol: tcp, description: "Node Exporter" }
```

#### Prometheus Stack Ports
```yaml
# When Prometheus Stack is enabled
prometheus_ports:
  - { port: 9090, protocol: tcp, description: "Prometheus Server" }
  - { port: 3000, protocol: tcp, description: "Grafana Dashboard" }
  - { port: 9093, protocol: tcp, description: "Alertmanager" }
  - { port: 9091, protocol: tcp, description: "Pushgateway" }
```

#### NIM Operator Ports
```yaml
# When NIM components are enabled
nim_ports:
  - { port: 8000, protocol: tcp, description: "NIM Inference API" }
  - { port: 8001, protocol: tcp, description: "NIM Management API" }
  - { port: 8002, protocol: tcp, description: "NIM Metrics" }
```

#### KEDA Autoscaler Ports
```yaml
# When KEDA is enabled
keda_ports:
  - { port: 8080, protocol: tcp, description: "KEDA Metrics Server" }
  - { port: 8443, protocol: tcp, description: "KEDA Webhook" }
```

#### Smart Scaler Inference Ports
```yaml
# When Smart Scaler inference is enabled
smart_scaler_inference_ports:
  - { port: 9900, protocol: tcp, description: "Inference API" }
  - { port: 8265, protocol: tcp, description: "Ray Dashboard" }
  - { port: 4321, protocol: tcp, description: "Custom Service" }
  - { port: 6379, protocol: tcp, description: "Redis State Store" }
```

## Usage

### Enabling Firewall Configuration

1. **Enable firewall management in your configuration**:
   ```yaml
   kubernetes_deployment:
     firewall:
       enabled: true
   ```

2. **Add custom ports if needed**:
   ```yaml
   firewall:
     enabled: true
     allow_additional_ports:
       - "8080"    # Custom HTTP service
       - "9999"    # Custom application
   ```

3. **Run the Kubernetes setup script**:
   ```bash
   # Deploy Kubernetes with firewall configuration
   ./setup_kubernetes.sh
   ```

4. **Deploy Smart Scaler components**:
   ```bash
   # Deploy components with automatic port management
   ansible-playbook site.yml
   ```

### Custom Port Configuration

For applications requiring specific ports:

```yaml
firewall:
  enabled: true
  allow_additional_ports:
    - "8080"      # Alternative HTTP
    - "9000"      # Custom service
    - "5432"      # PostgreSQL
    - "3306"      # MySQL
    - "6379"      # Redis
    - "9200"      # Elasticsearch
    - "5601"      # Kibana
```

## Validation and Testing

### Firewall Status Verification

```bash
# Check overall firewall status
sudo ufw status verbose

# Check specific port status
sudo ufw status numbered

# Verify port accessibility from external host
nc -zv [NODE_IP] [PORT]

# Test internal cluster communication
kubectl run test-pod --image=busybox --rm -it -- nc -zv [SERVICE_IP] [PORT]
```

### Component-Specific Testing

1. **Kubernetes API Server**:
   ```bash
   # Test API server accessibility
   kubectl cluster-info
   curl -k https://[NODE_IP]:6443/version
   ```

2. **Prometheus Monitoring**:
   ```bash
   # Test Prometheus access
   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
   curl http://localhost:9090/api/v1/targets
   ```

3. **Grafana Dashboard**:
   ```bash
   # Test Grafana access
   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
   curl http://localhost:3000/api/health
   ```

4. **NIM Inference Service**:
   ```bash
   # Test NIM service accessibility
   kubectl port-forward -n nim svc/meta-llama3-8b-instruct 8000:8000
   curl -X POST http://localhost:8000/v1/completions \
     -H "Content-Type: application/json" \
     -d '{"prompt": "Hello", "max_tokens": 10}'
   ```

5. **Smart Scaler Inference**:
   ```bash
   # Test Smart Scaler inference service
   kubectl port-forward -n smart-scaler svc/smart-scaler-llm-inf 9900:9900
   curl http://localhost:9900/health
   ```

## Troubleshooting

### Common Issues and Solutions

1. **Service Unreachable**
   ```bash
   # Check if port is open
   sudo ufw status | grep [PORT]
   
   # Verify service is running
   kubectl get svc -A | grep [SERVICE_NAME]
   
   # Check pod status
   kubectl get pods -A | grep [POD_NAME]
   ```

2. **Port Conflicts**
   ```bash
   # Check what's using a port
   sudo netstat -tulpn | grep [PORT]
   
   # Check UFW rules
   sudo ufw status numbered
   
   # Remove conflicting rule
   sudo ufw delete [RULE_NUMBER]
   ```

3. **External Access Issues**
   ```bash
   # Test from external host
   telnet [NODE_IP] [PORT]
   
   # Check NodePort services
   kubectl get svc -A --field-selector spec.type=NodePort
   
   # Verify ingress configuration
   kubectl get ingress -A
   ```

4. **Internal Cluster Communication**
   ```bash
   # Test pod-to-pod communication
   kubectl exec -it [POD_A] -- nc -zv [POD_B_IP] [PORT]
   
   # Check service discovery
   kubectl exec -it [POD] -- nslookup [SERVICE_NAME]
   
   # Verify network policies
   kubectl get networkpolicies -A
   ```

### Advanced Troubleshooting

1. **Firewall Log Analysis**
   ```bash
   # Check UFW logs
   sudo tail -f /var/log/ufw.log
   
   # Filter by specific port
   sudo grep "DPT=[PORT]" /var/log/ufw.log
   
   # Check for blocked connections
   sudo grep "BLOCK" /var/log/ufw.log
   ```

2. **Network Connectivity Testing**
   ```bash
   # Test TCP connectivity
   nc -zv [IP] [PORT]
   
   # Test UDP connectivity
   nc -uzv [IP] [PORT]
   
   # Continuous monitoring
   watch -n 1 'nc -zv [IP] [PORT]'
   ```

3. **Service Mesh Debugging**
   ```bash
   # Check Calico status
   kubectl get pods -n kube-system -l k8s-app=calico-node
   
   # Verify Calico BGP peers
   kubectl exec -n kube-system [CALICO_POD] -- calicoctl node status
   
   # Check Calico IP pools
   kubectl exec -n kube-system [CALICO_POD] -- calicoctl get ippool -o wide
   ```

## Security Best Practices

### 1. Principle of Least Privilege
- Only open ports required for specific components
- Regularly audit and remove unused ports
- Use specific IP ranges when possible
- Implement network segmentation

### 2. Monitoring and Alerting
```yaml
# Example Prometheus alert for unexpected port access
- alert: UnexpectedPortAccess
  expr: increase(firewall_blocked_connections[5m]) > 10
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "High number of blocked connections detected"
```

### 3. Regular Security Audits
```bash
# Audit open ports
sudo ss -tulpn

# Check firewall rules
sudo ufw status verbose

# Review network policies
kubectl get networkpolicies -A -o yaml
```

## Disabling Firewall Management

To disable firewall management:

1. **Update configuration**:
   ```yaml
   kubernetes_deployment:
     firewall:
       enabled: false
   ```

2. **Manual cleanup (if needed)**:
   ```bash
   # Remove all UFW rules (caution!)
   sudo ufw --force reset
   
   # Disable UFW
   sudo ufw disable
   ```

Note: Disabling firewall management will not remove existing rules but will skip firewall tasks in future deployments.

## Best Practices

### 1. Security
- Regularly review and audit firewall rules
- Implement least-privilege access
- Document all custom configurations

### 2. Maintenance
- Keep rule sets minimal and necessary
- Regular validation of configurations
- Maintain backup of working configurations

### 3. Monitoring
- Log firewall activities
- Monitor blocked connections
- Track rule effectiveness

## Related Documentation

- [User Input Configuration Guide](USER_INPUT_CONFIGURATION.md) - Complete configuration guide
- [User Input Reference](USER_INPUT_REFERENCE.md) - Detailed configuration reference
- [Kubernetes Configuration](KUBERNETES_CONFIGURATION.md) - Kubernetes cluster setup
- [NVIDIA Container Runtime](NVIDIA_CONTAINER_RUNTIME.md) - GPU runtime configuration 