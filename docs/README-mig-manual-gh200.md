# Manual MIG Configuration for 7x 1g.12gb on NVIDIA GH200 with GPU Operator

This guide documents how to manually configure 7x 1g.12gb MIG slices on an NVIDIA GH200 GPU in a Kubernetes cluster managed by the NVIDIA GPU Operator, including troubleshooting and example outputs.

---

## Prerequisites
- NVIDIA GH200 GPU (MIG-capable)
- Kubernetes cluster with GPU Operator installed (Helm chart v25.3.0 or similar)
- Helm and kubectl access
- Node running the GPU is accessible via SSH

---

## 1. Prepare GPU Operator for Manual MIG Management

### a. Disable the MIG Manager
Add to your `gpu-values.yaml`:
```yaml
migManager:
  enabled: false
```

### b. Ensure Device Plugin is in MIG Mode
Set this in your `gpu-values.yaml` (at the top level of `devicePlugin:`):
```yaml
devicePlugin:
  migStrategy: single
  tolerations:
    - effect: NoSchedule
      key: kubeslice.io/egs
      operator: Equal
      value: dedicated-node
```

### c. Upgrade the GPU Operator
```bash
helm upgrade gpu-operator nvidia/gpu-operator -n gpu-operator -f gpu-values.yaml
```

#### Example output:
```
Release "gpu-operator" has been upgraded. Happy Helming!
NAME: gpu-operator
LAST DEPLOYED: ...
NAMESPACE: gpu-operator
STATUS: deployed
REVISION: ...
...
```

### d. Remove Any MIG Config Node Label
```bash
kubectl label node master-1 nvidia.com/mig.config-
```
#### Example output:
```
node/master-1 labeled
```

---

## 2. Manually Configure 7x 1g.12gb MIG Slices

### a. SSH to the Node
```bash
ssh <your-node>
```

### b. Enable MIG Mode
```bash
nvidia-smi -i 0 -mig 1
```
#### Example output:
```
Enabled MIG Mode for GPU 00000009:01:00.0

Warning: persistence mode is disabled on device 00000009:01:00.0. See the Known Issues section of the nvidia-smi(1) man page for more information. Run with [--help | -h] switch to get more information on how to enable persistence mode.
All done.
```

### c. Delete Existing MIG Instances (if any)
```bash
nvidia-smi mig -dci
```
#### Example output (no instances):
```
No GPU instances found: Not Found
```
#### Example output (if instances existed):
```
Successfully destroyed compute instance ID 0 on GPU 0 GPU instance ID 7
Successfully destroyed GPU instance ID 7 on GPU 0
...
```

### d. Create 7x 1g.12gb GPU Instances
```bash
nvidia-smi mig -cgi 19,19,19,19,19,19,19 -C
```
#### Example output:
```
Successfully created GPU instance ID 13 on GPU  0 using profile MIG 1g.12gb (ID 19)
Successfully created compute instance ID  0 on GPU  0 GPU instance ID 13 using profile MIG 1g.12gb (ID  0)
Successfully created GPU instance ID 11 on GPU  0 using profile MIG 1g.12gb (ID 19)
Successfully created compute instance ID  0 on GPU  0 GPU instance ID 11 using profile MIG 1g.12gb (ID  0)
Successfully created GPU instance ID 12 on GPU  0 using profile MIG 1g.12gb (ID 19)
Successfully created compute instance ID  0 on GPU  0 GPU instance ID 12 using profile MIG 1g.12gb (ID  0)
Successfully created GPU instance ID  7 on GPU  0 using profile MIG 1g.12gb (ID 19)
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  7 using profile MIG 1g.12gb (ID  0)
Successfully created GPU instance ID  8 on GPU  0 using profile MIG 1g.12gb (ID 19)
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  8 using profile MIG 1g.12gb (ID  0)
Successfully created GPU instance ID  9 on GPU  0 using profile MIG 1g.12gb (ID 19)
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  9 using profile MIG 1g.12gb (ID  0)
Successfully created GPU instance ID 10 on GPU  0 using profile MIG 1g.12gb (ID 19)
Successfully created compute instance ID  0 on GPU  0 GPU instance ID 10 using profile MIG 1g.12gb (ID  0)
```

### e. List GPU Instance IDs
```bash
nvidia-smi mig -lgi
```
#### Example output:
```
+-------------------------------------------------------+
| GPU instances:                                        |
| GPU   Name             Profile  Instance   Placement  |
|                          ID       ID       Start:Size |
|=======================================================|
|   0  MIG 1g.12gb         19        7          0:1     |
+-------------------------------------------------------+
|   0  MIG 1g.12gb         19        8          1:1     |
+-------------------------------------------------------+
|   0  MIG 1g.12gb         19        9          2:1     |
+-------------------------------------------------------+
|   0  MIG 1g.12gb         19       10          3:1     |
+-------------------------------------------------------+
|   0  MIG 1g.12gb         19       11          4:1     |
+-------------------------------------------------------+
|   0  MIG 1g.12gb         19       12          5:1     |
+-------------------------------------------------------+
|   0  MIG 1g.12gb         19       13          6:1     |
+-------------------------------------------------------+
```

### f. Create Compute Instances for Each GPU Instance
For each GPU instance ID (e.g., 7-13):
```bash
nvidia-smi mig -gi <ID> -cci
```
#### Example output (if not already created):
```
Successfully created compute instance ID 0 on GPU 0 GPU instance ID 7 using profile MIG 1g.12gb (ID 0)
```
#### If already created (as in the above creation step), this may not be needed.

### g. Verify Compute Instances
```bash
nvidia-smi mig -lci
```
#### Example output:
```
+--------------------------------------------------------------------+
| Compute instances:                                                 |
| GPU     GPU       Name             Profile   Instance   Placement  |
|       Instance                       ID        ID       Start:Size |
|         ID                                                         |
|====================================================================|
|   0      7       MIG 1g.12gb          0         0          0:1     |
+--------------------------------------------------------------------+
|   0      8       MIG 1g.12gb          0         0          0:1     |
+--------------------------------------------------------------------+
|   0      9       MIG 1g.12gb          0         0          0:1     |
+--------------------------------------------------------------------+
|   0     10       MIG 1g.12gb          0         0          0:1     |
+--------------------------------------------------------------------+
|   0     11       MIG 1g.12gb          0         0          0:1     |
+--------------------------------------------------------------------+
|   0     12       MIG 1g.12gb          0         0          0:1     |
+--------------------------------------------------------------------+
|   0     13       MIG 1g.12gb          0         0          0:1     |
+--------------------------------------------------------------------+
```

### h. List All MIG Devices
```bash
nvidia-smi -L
```
#### Example output:
```
GPU 0: NVIDIA GH200 480GB (UUID: GPU-436e9429-c2d8-2069-f1ee-fac0bfdb63a8)
  MIG 1g.12gb     Device  0: (UUID: MIG-af275571-0fa8-5fb7-b067-2737ee7c9565)
  MIG 1g.12gb     Device  1: (UUID: MIG-4bda24b1-cedc-573f-80da-7e67b42407bb)
  MIG 1g.12gb     Device  2: (UUID: MIG-bed33bf1-f571-564e-a249-b446ade09b6b)
  MIG 1g.12gb     Device  3: (UUID: MIG-d9496a92-97ff-5197-9886-1104c347c631)
  MIG 1g.12gb     Device  4: (UUID: MIG-ffb806a6-dcf9-5b50-b110-3a6688e516d0)
  MIG 1g.12gb     Device  5: (UUID: MIG-bf8d364b-f108-529f-8505-11abf5917d02)
  MIG 1g.12gb     Device  6: (UUID: MIG-661b56b4-49f1-5f60-aa8c-699517e8c7ba)
```

---

## 3. Verify Kubernetes Sees the MIG Devices

### a. Check Node Resources
```bash
kubectl describe node master-1 | grep nvidia.com
```
#### Example output (success):
```
nvidia.com/mig-1g.12gb: 7
```
#### Example output (if not working yet):
```
nvidia.com/gpu: 1
```

### b. Troubleshooting
- If you only see `nvidia.com/gpu: 1`, ensure the device plugin DaemonSet is running with `--mig-strategy=single`.
- If not, edit the DaemonSet manually or ensure your Helm values are correct and re-upgrade.
- Restart the device plugin pod if needed:
  ```bash
  kubectl -n gpu-operator delete pod -l app=nvidia-device-plugin
  ```
- Check device plugin logs for errors:
  ```bash
  kubectl -n gpu-operator logs -l app=nvidia-device-plugin
  ```
#### Example log output (missing argument):
```
No --mig-strategy argument found, defaulting to none. Only nvidia.com/gpu will be advertised.
```

---

## 4. Test Pod Scheduling (Optional)

Example pod YAML:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mig-test
spec:
  containers:
  - name: cuda-container
    image: nvidia/cuda:12.8.0-base-ubuntu22.04
    command: ["sleep", "3600"]
    resources:
      limits:
        nvidia.com/mig-1g.12gb: 1
  restartPolicy: Never
```
Apply and check:
```bash
kubectl apply -f mig-test.yaml
kubectl get pods
kubectl describe pod mig-test
```
#### Example output:
```
Name:         mig-test
Namespace:    default
...
Limits:
  nvidia.com/mig-1g.12gb:  1
...
```

---

## 5. Key Notes
- The GPU Operator will **not** override your manual MIG config if `migManager.enabled: false` and no `nvidia.com/mig.config` label is set.
- Metrics and scheduling will work as expected with the device plugin in `migStrategy: single` mode.
- Only built-in profiles are supported for automatic slicing; for custom layouts like 7x 1g.12gb, manual configuration is required.
- If you see `nvidia.com/gpu: 1` instead of `nvidia.com/mig-1g.12gb: 7`, check the device plugin arguments and logs.

---

## 6. References
- [NVIDIA GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/)
- [NVIDIA MIG User Guide](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/) 