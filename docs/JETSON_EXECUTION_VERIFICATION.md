# Jetson Role Execution Verification Guide

## 🎯 **Overview**

This guide explains how to confirm that all Jetson-related Ansible roles are properly running during the `setup_k3s.sh` execution process.

## 🔍 **Verification Points**

### **1. Pre-Execution Verification**
The script now checks these items before running Ansible:

- ✅ **Configuration Check**: Verifies `jetson_prerequisites.enabled` in `user_input.yml`
- ✅ **Role Files**: Confirms Jetson role files exist in `k3s-ansible/roles/`
- ✅ **Role Structure**: Validates tasks and defaults files are present

### **2. During Execution Verification**
The script logs and tracks:

- ✅ **Role Execution**: Confirms `jetson_prerequisites` role runs
- ✅ **Task Count**: Shows how many Jetson tasks executed
- ✅ **Detection Results**: Verifies Jetson detection completed
- ✅ **jtop.sock Status**: Confirms socket verification ran

### **3. Post-Execution Verification**
After Ansible completes, the script:

- ✅ **Logs Analysis**: Searches for Jetson role execution evidence
- ✅ **Success Indicators**: Confirms key verification steps completed
- ✅ **Status Summary**: Provides overall execution status

## 📋 **What Gets Verified**

### **Configuration Verification**
```yaml
# In user_input.yml
jetson_prerequisites:
  enabled: true                    # ✅ Must be true
  jetson_stats:
    force_reinstall: false
    upgrade: true
    python_version: "python3"
```

### **Role File Verification**
```
k3s-ansible/roles/jetson_prerequisites/
├── tasks/main.yml                 # ✅ Main role logic
├── defaults/main.yml              # ✅ Default configuration
├── meta/main.yml                  # ✅ Role metadata
└── README.md                      # ✅ Documentation
```

### **Execution Verification**
```
✅ Role: jetson_prerequisites
✅ Target: ALL nodes in inventory
✅ Execution: During K3s deployment (first play)
✅ Configuration: From user_input.yml
```

## 🔍 **How to Check**

### **1. During Execution**
Watch for these messages in the terminal:

```bash
🔍 Pre-execution Jetson role verification...
✓ Jetson prerequisites enabled in user_input.yml
✓ Jetson role directory exists
✓ Jetson role tasks file exists
✓ Jetson role defaults file exists

🔧 Jetson prerequisites will be executed on all nodes during K3s deployment
This ensures Jetson devices are detected and configured before cluster setup

🔍 Verifying Jetson role execution...
✓ Jetson role execution found in logs
✓ Jetson role executed with X tasks
✓ Jetson detection completed successfully
✓ jtop.sock verification completed
```

### **2. In Ansible Logs**
Check `output/ansible.log` for:

```
JETSON ROLE EXECUTION PLAN:
============================
Role: jetson_prerequisites
Target: ALL nodes in inventory
Execution: During K3s deployment (first play)
Configuration: From user_input.yml jetson_prerequisites section

JETSON ROLE EXECUTION VERIFICATION:
===================================
✓ Jetson role execution found in logs
✓ Jetson role executed with X tasks
✓ Jetson detection completed successfully
✓ jtop.sock verification completed
```

### **3. In Ansible Output**
Look for these task names:

```
TASK [jetson_prerequisites : Check if Jetson detection is enabled]
TASK [jetson_prerequisites : Check if this is a Jetson device]
TASK [jetson_prerequisites : Install jetson-stats on Jetson devices]
TASK [jetson_prerequisites : Check for jtop.sock file on Jetson nodes]
TASK [jetson_prerequisites : Jetson verification summary for Jetson nodes]
```

## 🚨 **Troubleshooting**

### **If Jetson Role Doesn't Run:**

1. **Check Configuration**
   ```bash
   # Verify in user_input.yml
   jetson_prerequisites:
     enabled: true  # Must be true
   ```

2. **Check Role Files**
   ```bash
   # Ensure role exists
   ls -la k3s-ansible/roles/jetson_prerequisites/
   ```

3. **Check Ansible Playbook**
   ```bash
   # Verify role is included
   cat k3s-ansible/playbooks/site.yml
   ```

4. **Check Logs**
   ```bash
   # Look for Jetson execution
   grep -i "jetson" output/ansible.log
   ```

### **Common Issues:**

- **Role Not Found**: Jetson role not copied to k3s-ansible
- **Configuration Disabled**: `enabled: false` in user_input.yml
- **Role Syntax Error**: YAML syntax issues in role files
- **Permission Issues**: Role files not readable by Ansible

## 📊 **Expected Output**

### **Successful Execution:**
```
🎯 Jetson Verification Summary:
================================
✅ Device Detection: PASS
✅ jetson-stats Installation: PASS
✅ jtop Command Test: PASS
✅ jtop.sock File: PASS
✅ jtop Service: PASS
✅ Service Configuration: PASS
✅ Boot Enabled: PASS
✅ Socket Connectivity: PASS
✅ Container Access: PASS

📊 Overall Status: EXCELLENT
```

### **Non-Jetson Node:**
```
📍 Node Type: Standard Node
🔧 Role Status: SKIPPED (Not Applicable)
✅ This node is ready for K3s deployment (no Jetson-specific setup needed)
```

## 🎉 **Summary**

The enhanced verification ensures:

1. **Pre-Flight Check**: Role configuration and files verified before execution
2. **Execution Tracking**: Comprehensive logging of Jetson role execution
3. **Post-Execution Verification**: Confirmation that all expected tasks completed
4. **Clear Feedback**: Detailed status reporting for troubleshooting

With these verifications, you can be confident that Jetson roles are running properly during `setup_k3s.sh` execution!
