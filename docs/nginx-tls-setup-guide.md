# TLS Certificate Generation and NGINX Ingress Configuration Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation Steps](#installation-steps)
3. [Verification Steps](#verification-steps)
4. [Optional DNS Configuration Options](#optional-dns-configuration-options)
5. [Troubleshooting Guide](#troubleshooting-guide)

## Prerequisites
- Kubernetes cluster is set up and running
- `kubectl` is configured to interact with your cluster
- `helm` is installed
- `openssl` is installed

## Installation Steps

### 1. Certificate Generation
```bash
# Generate the certificate and private key
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout supermicro-tls.key \
  -out supermicro-tls.crt \
  -subj "/CN=master-1.supermicro.com" \
  -addext "subjectAltName=DNS:master-1.supermicro.com"
```

### 2. Kubernetes Secret Creation
```bash
# Create namespace if it doesn't exist
kubectl create namespace ingress-nginx

# Create the TLS secret
kubectl create secret tls supermicro-tls \
  --key supermicro-tls.key \
  --cert supermicro-tls.crt \
  -n ingress-nginx
```

### 3. NGINX Ingress Setup
```bash
# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install the ingress-nginx controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.extraArgs.default-ssl-certificate=ingress-nginx/supermicro-tls \
  --set controller.service.type=LoadBalancer
```

### 4. Load Balancer Configuration
```bash
# Get the external IP/hostname of the load balancer
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

## Verification Steps

### 1. Certificate Verification
```bash
# View certificate details
openssl x509 -in supermicro-tls.crt -text -noout
```

### 2. TLS Connection Testing
```bash
# Test HTTPS connection
curl -v -k https://<INGRESS_IP> --header "Host: master-1.supermicro.com"
```

Expected Output Indicators:
- TLS Connection: `SSL connection using TLSv1.3`
- Certificate Details: Should show correct domain and dates
- HTTP Response: 404 is normal without backend configuration


## Optional DNS Configuration Options

### Option 1: Local Host Entry
```bash
# Add to /etc/hosts (requires root/sudo)
sudo sh -c 'echo "<INGRESS_IP> master-1.supermicro.com" >> /etc/hosts'
```

### Option 2: Temporary Resolution
```bash
# Test with custom DNS resolution
curl -v -k https://master-1.supermicro.com --resolve master-1.supermicro.com:443:<INGRESS_IP>
```

### Option 3: Direct IP Access
```bash
# Test using IP with Host header
curl -v -k https://<INGRESS_IP> --header "Host: master-1.supermicro.com"
```

## Troubleshooting Guide

### Common Issues

1. **Certificate Validation**
```bash
# Check certificate in secret
kubectl get secret supermicro-tls -n ingress-nginx -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# Check NGINX logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

2. **Network Connectivity**
```bash
# Check NGINX configuration
kubectl exec -it -n ingress-nginx $(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}') -- cat /etc/nginx/nginx.conf

# Check TLS configuration
kubectl get ingress -A -o yaml | grep -i tls -A 5
```

### HTTP Response Codes
- **404**: Expected response without backend configuration
- **503**: Backend service unavailable
- **502**: Gateway or proxy configuration issue
