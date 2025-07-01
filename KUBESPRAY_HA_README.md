# Kubespray Multi-Master HA Configuration Guide

This guide explains how to configure multi-master Kubernetes clusters with load balancing and etcd HA using the integrated `user_input.yml` approach.

## Overview

The enhanced configuration now supports:
- ✅ **Multi-Master HA** with 3+ control plane nodes
- ✅ **Automatic Load Balancer** configuration (Nginx/HAProxy/kube-vip/External)
- ✅ **etcd HA** with events cluster separation
- ✅ **Dynamic Configuration Generation** from `user_input.yml`
- ✅ **Built-in Validation** and error checking

## Quick Start

### 1. Configure Multi-Master Setup

Edit `user_input.yml` to enable HA:

```yaml
kubernetes_deployment:
  enabled: true
  
  # Add multiple control plane nodes (minimum 3 for HA)
  control_plane_nodes:
    - name: "master-1"
      ansible_host: "10.0.1.10"
      private_ip: "10.0.1.10"
      ansible_user: "ubuntu"
      # ... other settings
    - name: "master-2"
      ansible_host: "10.0.1.11"
      private_ip: "10.0.1.11"
      ansible_user: "ubuntu"
      # ... other settings
    - name: "master-3"
      ansible_host: "10.0.1.12"
      private_ip: "10.0.1.12"
      ansible_user: "ubuntu"
      # ... other settings
      
  # Enable load balancer (already configured by default)
  load_balancer:
    enabled: true
    type: "localhost"  # or "external" or "kube-vip"
    
  # Enable etcd HA (already configured by default)
  etcd_ha:
    enabled: true
```

### 2. Deploy the Cluster

```bash
# Enable Kubernetes deployment
sed -i 's/enabled: false/enabled: true/' user_input.yml

# Run the deployment (automatically generates Kubespray configs)
./setup_kubernetes.sh
```

## Load Balancer Options

### Option 1: Localhost Load Balancer (Recommended)

**Best for**: Most deployments, simple setup, runs on each node

```yaml
load_balancer:
  enabled: true
  type: "localhost"
  localhost:
    enabled: true
    lb_type: "nginx"        # or "haproxy"
    port: 6443
    healthcheck_port: 8081
    memory_requests: "32M"
    cpu_requests: "25m"
```

**How it works**: 
- Runs nginx/haproxy pod on each node
- Each kubelet/kubectl connects to `localhost:6443`
- Local LB forwards to healthy API servers

### Option 2: External Load Balancer

**Best for**: Cloud environments, existing infrastructure

```yaml
load_balancer:
  enabled: true
  type: "external"
  external:
    enabled: true
    address: "10.0.1.100"           # Your LB IP
    port: 6443
    domain_name: "k8s-api.yourdomain.com"  # Optional
```

**Requirements**: 
- Pre-existing load balancer (HAProxy, Nginx, Cloud LB)
- Points to all control plane nodes on port 6443

### Option 3: kube-vip (Advanced)

**Best for**: On-premises, VIP requirements

```yaml
load_balancer:
  enabled: true
  type: "kube-vip"
  kube_vip:
    enabled: true
    vip_address: "10.0.1.100"       # Virtual IP
    interface: "eth0"
    arp_enabled: true
    leader_election: true
```

## etcd HA Configuration

### Basic etcd HA

```yaml
etcd_ha:
  enabled: true
  deployment_type: "kubeadm"      # or "external"
  
  # Events cluster separation (recommended)
  events_cluster:
    enabled: true
    setup: true
```

### Advanced etcd Tuning

```yaml
etcd_ha:
  enabled: true
  cluster:
    heartbeat_interval: "100"     # ms
    election_timeout: "1000"      # ms
    quota_backend_bytes: "2147483648"  # 2GB
    auto_compaction_retention: "8"     # hours
  
  security:
    peer_auto_tls: false         # Use proper certificates
    client_cert_auth: true
    peer_cert_auth: true
    
  performance:
    max_snapshots: 5
    max_wals: 5
    snapshot_count: 100000
```

## Validation and Troubleshooting

### Automatic Validation

The `setup_kubernetes.sh` script automatically validates:

- ✅ Multi-master node count (minimum 3)
- ✅ Load balancer configuration consistency
- ✅ etcd HA settings
- ✅ Generated Kubespray configurations
- ✅ SSH connectivity to all nodes

### Generated Files

The script creates:
- `inventory/kubespray/inventory.ini` - Ansible inventory
- `inventory/kubespray/group_vars/all/all.yml` - Kubespray variables

### Manual Verification

```bash
# Check generated configuration
cat inventory/kubespray/group_vars/all/all.yml

# Verify cluster after deployment
kubectl get nodes
kubectl get pods -n kube-system
kubectl get endpoints kubernetes

# Check etcd cluster
kubectl get pods -n kube-system | grep etcd
```

## Architecture Examples

### 3-Node HA Cluster with Local LB

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   Master-1  │  │   Master-2  │  │   Master-3  │
│ API:6443    │  │ API:6443    │  │ API:6443    │
│ etcd        │  │ etcd        │  │ etcd        │
│ nginx-proxy │  │ nginx-proxy │  │ nginx-proxy │
└─────────────┘  └─────────────┘  └─────────────┘
       ▲                ▲                ▲
       │                │                │
       └────────────────┼────────────────┘
                        │
           ┌─────────────▼─────────────┐
           │      Worker Nodes         │
           │   kubectl → localhost:6443 │
           └───────────────────────────┘
```

### 3-Node HA with External LB

```
              ┌─────────────────┐
              │ External LB     │
              │ (HAProxy/Nginx) │
              │ 10.0.1.100:6443 │
              └─────────┬───────┘
                        │
         ┌──────────────┼──────────────┐
         ▼              ▼              ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   Master-1  │  │   Master-2  │  │   Master-3  │
│ API:6443    │  │ API:6443    │  │ API:6443    │
│ etcd        │  │ etcd        │  │ etcd        │
└─────────────┘  └─────────────┘  └─────────────┘
```

## Common Configurations

### Production HA Setup

```yaml
# Minimum 3 masters for true HA
control_plane_nodes: [master-1, master-2, master-3]

# Localhost LB for simplicity
load_balancer:
  type: "localhost"
  localhost:
    lb_type: "nginx"

# Full etcd HA with events separation
etcd_ha:
  enabled: true
  events_cluster:
    enabled: true

# Add dedicated worker nodes
worker_nodes: [worker-1, worker-2, worker-3]
```

### Development HA Setup

```yaml
# 3 masters (can be smaller VMs)
control_plane_nodes: [master-1, master-2, master-3]

# Localhost LB
load_balancer:
  type: "localhost"

# Basic etcd HA
etcd_ha:
  enabled: true
  events_cluster:
    enabled: false  # Save resources
```

## Migration from Single Master

1. **Add new master nodes** to `control_plane_nodes`
2. **Enable load balancer** configuration
3. **Enable etcd HA** settings
4. **Run deployment**: `./setup_kubernetes.sh`

The script handles the migration automatically through Kubespray.

## Troubleshooting

### Load Balancer Issues

```bash
# Check nginx-proxy pods
kubectl get pods -n kube-system | grep nginx-proxy

# Check LB logs
kubectl logs -n kube-system -l k8s-app=kube-nginx

# Test API server connectivity
curl -k https://localhost:6443/healthz
```

### etcd Issues

```bash
# Check etcd cluster health
kubectl exec -n kube-system etcd-master-1 -- etcdctl cluster-health

# Check etcd endpoints
kubectl get endpoints kubernetes -o yaml
```

### Validation Failures

If `setup_kubernetes.sh` reports validation errors:

1. Check the generated configuration files
2. Verify node count (minimum 3 for HA)
3. Ensure load balancer settings are consistent
4. Check SSH connectivity to all nodes

## Best Practices

1. **Always use odd number of masters** (3, 5, 7)
2. **Enable etcd events separation** for production
3. **Use localhost LB** for simplicity unless you have specific requirements
4. **Test SSH connectivity** before deployment
5. **Backup etcd data** regularly in production
6. **Monitor etcd cluster health** and performance 