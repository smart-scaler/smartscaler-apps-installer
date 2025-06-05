#!/bin/bash
# Enable command logging and error handling
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Logging setup
LOG_DIR="$(pwd)/logs"
LOG_FILE="${LOG_DIR}/kubernetes-deploy.log"
ANSIBLE_OUTPUT_LOG="${LOG_DIR}/ansible-output.log"
ASYNC_LOG="${LOG_DIR}/async-tasks.log"
STARTTIME=$(date +%Y-%m-%d_%H-%M-%S)

# Create logs directory with proper permissions
create_log_directory() {
    # Create log directory if it doesn't exist
    if [ ! -d "${LOG_DIR}" ]; then
        mkdir -p "${LOG_DIR}" || {
            echo "ERROR: Failed to create log directory ${LOG_DIR}"
            exit 1
        }
        chmod 755 "${LOG_DIR}" || {
            echo "ERROR: Failed to set permissions on ${LOG_DIR}"
            exit 1
        }
    fi
    
    # Ensure log files exist and have proper permissions
    for log_file in "${LOG_FILE}" "${ANSIBLE_OUTPUT_LOG}" "${ASYNC_LOG}"; do
        if [ ! -f "${log_file}" ]; then
            touch "${log_file}" || {
                echo "ERROR: Failed to create log file ${log_file}"
                exit 1
            }
        fi
        chmod 644 "${log_file}" || {
            echo "ERROR: Failed to set permissions on ${log_file}"
            exit 1
        }
    done
    
    # Set ownership if running with sudo
    if [ -n "$SUDO_USER" ]; then
        chown -R "$SUDO_USER:$SUDO_USER" "${LOG_DIR}" || {
            echo "ERROR: Failed to set ownership on ${LOG_DIR}"
            exit 1
        }
    fi

    # Add script start marker to main log
    {
        echo "=== Script started at $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo "Command: $0 $@"
        echo "Working directory: $(pwd)"
        echo "User: $(whoami)"
        echo "================================="
    } >> "${LOG_FILE}" || {
        echo "ERROR: Failed to write to log file ${LOG_FILE}"
        exit 1
    }
}

# Create log directory before anything else
create_log_directory "$@"

# Now setup output redirection after log directory is created
exec 1> >(tee -a "${LOG_FILE}")
exec 2> >(tee -a "${LOG_FILE}" >&2)

# Enhanced logging function with debug support
log() {
    local message="$1"
    local color=${2:-$NC}
    local level=${3:-INFO}
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Format the log message
    local formatted_message="${timestamp} [${level}] ${message}"
    
    # Log to file (without color)
    echo -e "${formatted_message}" >> "${LOG_FILE}"
    
    # Display to console with color and proper indentation
    echo -e "    ${color}${message}${NC}"
}

log_debug() {
    log "$1" "${BLUE}" "DEBUG"
}

log_info() {
    log "$1" "${NC}" "INFO"
}

log_error() {
    log "$1" "${RED}" "ERROR"
}

log_success() {
    log "$1" "${GREEN}" "SUCCESS"
}

log_warning() {
    log "$1" "${YELLOW}" "WARNING"
}

log_section() {
    local section=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local separator="=== ${section} ==="
    local line=$(printf '%*s' "${#separator}" '' | tr ' ' '=')
    
    # Log to file
    echo -e "\n${timestamp} ${line}" >> "${LOG_FILE}"
    echo -e "${timestamp} ${separator}" >> "${LOG_FILE}"
    echo -e "${timestamp} ${line}\n" >> "${LOG_FILE}"
    
    # Display to console
    echo -e "\n${BOLD}${GREEN}${separator}${NC}"
}

log_command() {
    local cmd="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log the command being executed
    echo -e "${timestamp} [COMMAND] Executing: ${cmd}" | tee -a "${LOG_FILE}"
    
    # Execute the command through bash to properly handle shell features
    local output
    if output=$(bash -c "${cmd}" 2>&1); then
        echo -e "${timestamp} [COMMAND] Command succeeded" | tee -a "${LOG_FILE}"
        echo "${output}" | tee -a "${LOG_FILE}"
        return 0
    else
        local exit_code=$?
        echo -e "${timestamp} [COMMAND] Command failed with exit code ${exit_code}" | tee -a "${LOG_FILE}"
        echo "${output}" | tee -a "${LOG_FILE}"
        return ${exit_code}
    fi
}

# Function to log environment information
log_environment() {
    log_section "ENVIRONMENT INFORMATION"
    log_info "System Information:"
    log_command "uname -a"
    log_info "Python Version:"
    log_command "python3 --version"
    log_info "Ansible Version:"
    log_command "ansible --version"
    log_info "Environment Variables:"
    log_command "bash -c 'env | sort'"
}

# Log environment information
log_environment

# Function to log start of deployment
log_start() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    log_section "DEPLOYMENT START"
    log_info "Starting Kubernetes deployment at ${timestamp}"
    log_info "Start Time: ${STARTTIME}"
    
    # Log initial deployment information
    log_info "Deployment Configuration:"
    log_info "• Working Directory: $(pwd)"
    log_info "• Log Directory: ${LOG_DIR}"
    log_info "• Inventory Path: $(pwd)/inventory/kubespray/inventory.ini"
}

# Function to log end of deployment
log_end() {
    local ENDTIME=$(date +%Y-%m-%d_%H-%M-%S)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_section "DEPLOYMENT END"
    log_info "Deployment completed at ${timestamp}"
    
    # Calculate duration
    local start_epoch=$(date -d "${STARTTIME//_/ }" +%s 2>/dev/null)
    local end_epoch=$(date -d "${ENDTIME//_/ }" +%s 2>/dev/null)
    
    if [ ! -z "$start_epoch" ] && [ ! -z "$end_epoch" ]; then
        local duration=$((end_epoch - start_epoch))
        local hours=$((duration / 3600))
        local minutes=$(( (duration % 3600) / 60 ))
        local seconds=$((duration % 60))
        
        local duration_msg=""
        if [ $hours -gt 0 ]; then
            duration_msg="${hours}h ${minutes}m ${seconds}s"
        elif [ $minutes -gt 0 ]; then
            duration_msg="${minutes}m ${seconds}s"
        else
            duration_msg="${seconds}s"
        fi
        
        log_info "Total Duration: ${duration_msg}"
    else
        log_warning "Could not calculate deployment duration"
    fi
}

# Function to preserve color in logs
preserve_color_log() {
    local line="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} | ${line}" | tee -a "${LOG_FILE}"
}

# Start logging
log_start

# Check Python3 and pip3 installation
if ! command -v python3 &> /dev/null; then
    log_error "Python3 is not installed. Please install Python3 first."
    exit 1
fi

if ! command -v pip3 &> /dev/null; then
    log_error "pip3 is not installed. Please install pip3 first."
    exit 1
fi

# Check and install required Python packages
log_section "PYTHON PACKAGE CHECK"
log_info "Checking required Python packages..."

# Create a temporary Python script
TEMP_PYTHON_SCRIPT=$(mktemp)
cat > "${TEMP_PYTHON_SCRIPT}" << 'END_PYTHON'
import sys
import subprocess

def run_pip_command(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.STDOUT).decode().strip()
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Pip command failed: {e.output.decode()}")
        sys.exit(1)

try:
    required_packages = ['pyyaml', 'jinja2']
    print("INFO: Checking for required packages...")
    
    # Get list of installed packages
    pip_list = run_pip_command([sys.executable, '-m', 'pip', 'freeze'])
    installed_packages = [pkg.split('==')[0].lower() for pkg in pip_list.split('\n') if pkg]
    
    # Find missing packages
    missing_packages = [pkg for pkg in required_packages if pkg.lower() not in installed_packages]
    
    if missing_packages:
        print(f"WARNING: Installing missing packages: {', '.join(missing_packages)}")
        for package in missing_packages:
            print(f"INFO: Installing {package}...")
            result = run_pip_command([sys.executable, '-m', 'pip', 'install', package])
            print(f"SUCCESS: Successfully installed {package}")
    else:
        print("SUCCESS: All required packages are installed.")

except Exception as e:
    print(f"ERROR: {str(e)}")
    sys.exit(1)
END_PYTHON

# Run the Python script and process its output
python3 "${TEMP_PYTHON_SCRIPT}" 2>&1 | while IFS= read -r line; do
    if [[ $line == ERROR:* ]]; then
        log_error "${line#ERROR: }"
    elif [[ $line == WARNING:* ]]; then
        log_warning "${line#WARNING: }"
    elif [[ $line == SUCCESS:* ]]; then
        log_success "${line#SUCCESS: }"
    else
        log_info "$line"
    fi
done

# Store the Python script exit code
PYTHON_EXIT_CODE=${PIPESTATUS[0]}

# Clean up the temporary script
rm -f "${TEMP_PYTHON_SCRIPT}"

# Check if the Python script failed
if [ $PYTHON_EXIT_CODE -ne 0 ]; then
    log_error "Failed to install required Python packages (exit code: ${PYTHON_EXIT_CODE})"
    exit 1
fi

# Verify the packages were actually installed
python3 -c '
import yaml
import jinja2
print("SUCCESS: Required packages verified successfully.")
' 2>&1 | while IFS= read -r line; do
    if [[ $line == SUCCESS:* ]]; then
        log_success "${line#SUCCESS: }"
    else
        log_info "$line"
    fi
done

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    log_error "Failed to import required packages after installation"
    exit 1
fi

# Setup locale
log_section "LOCALE SETUP"
log_info "Setting up locale..."
if ! locale -a | grep -q "en_US.utf8"; then
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root to setup locale"
        exit 1
    fi
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y locales
    locale-gen en_US.UTF-8
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
fi

# Export locale variables
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

log_info "Checking if Kubernetes deployment is enabled..."

# Check if kubernetes deployment is enabled
KUBERNETES_ENABLED=$(python3 -c '
import yaml
import sys
import os

try:
    with open("user_input.yml", "r") as f:
        data = yaml.safe_load(f)
        if "kubernetes_deployment" not in data:
            print("Error: kubernetes_deployment section not found in user_input.yml", file=sys.stderr)
            sys.exit(1)
        if "enabled" not in data["kubernetes_deployment"]:
            print("Error: enabled field not found in kubernetes_deployment section", file=sys.stderr)
            sys.exit(1)
        print(str(data["kubernetes_deployment"]["enabled"]).lower())
except FileNotFoundError:
    print("Error: user_input.yml file not found", file=sys.stderr)
    sys.exit(1)
except yaml.YAMLError as e:
    print(f"Error parsing YAML: {str(e)}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"Error reading YAML: {str(e)}", file=sys.stderr)
    sys.exit(1)
')

if [ $? -ne 0 ]; then
    log_error "Error checking Kubernetes deployment status"
    exit 1
fi

if [ "$KUBERNETES_ENABLED" != "true" ]; then
    log_error "Kubernetes deployment is disabled in user_input.yml. Skipping setup."
    exit 0
fi

log_info "Starting Kubernetes deployment setup..."

# Create necessary directories
mkdir -p inventory/kubespray

log_info "Reading node information from user_input.yml..."

# Generate inventory from user_input.yml
python3 << EOF
import yaml
import os
import sys
from jinja2 import Template, Environment, FileSystemLoader

def validate_addresses(kubernetes_deployment):
    """Validate that all IP addresses are properly set."""
    api_host = kubernetes_deployment['api_server']['host']
    if api_host == "PUBLIC_IP":
        print("Warning: API server host is still set to PUBLIC_IP placeholder", file=sys.stderr)
        return False
    
    for node in kubernetes_deployment['control_plane_nodes']:
        if node['ansible_host'] == "PUBLIC_IP" or node.get('private_ip', "PRIVATE_IP") == "PRIVATE_IP":
            print(f"Warning: Node {node['name']} has placeholder IPs", file=sys.stderr)
            return False
    
    if 'worker_nodes' in kubernetes_deployment:
        for node in kubernetes_deployment['worker_nodes']:
            if node['ansible_host'] == "PUBLIC_IP" or node.get('private_ip', "PRIVATE_IP") == "PRIVATE_IP":
                print(f"Warning: Node {node['name']} has placeholder IPs", file=sys.stderr)
                return False
    
    return True

def format_ssl_addresses(kubernetes_deployment, control_plane_nodes, worker_nodes):
    """Format SSL addresses properly, removing duplicates and placeholders."""
    addresses = set()
    
    # Add API server host first
    api_host = kubernetes_deployment['api_server']['host']
    if api_host != "PUBLIC_IP":
        addresses.add(api_host)
    
    # Add control plane addresses
    for node in control_plane_nodes:
        if node['ansible_host'] != "PUBLIC_IP":
            addresses.add(node['ansible_host'])
        if node.get('private_ip', "PRIVATE_IP") != "PRIVATE_IP":
            addresses.add(node['private_ip'])
    
    # Add worker node addresses
    for node in worker_nodes:
        if node['ansible_host'] != "PUBLIC_IP":
            addresses.add(node['ansible_host'])
        if node.get('private_ip', "PRIVATE_IP") != "PRIVATE_IP":
            addresses.add(node['private_ip'])
    
    return sorted(list(addresses))

def verify_inventory(inventory_path):
    """Verify the generated inventory file."""
    with open(inventory_path, 'r') as f:
        content = f.read()
    
    # Check for common issues
    if "PUBLIC_IP" in content:
        print("Error: Generated inventory contains PUBLIC_IP placeholder", file=sys.stderr)
        return False
    
    if "PRIVATE_IP" in content:
        print("Error: Generated inventory contains PRIVATE_IP placeholder", file=sys.stderr)
        return False
    
    if "supplementary_addresses_in_ssl_keys=[]" in content:
        print("Error: Empty supplementary SSL addresses", file=sys.stderr)
        return False
    
    return True

try:
    # Read user_input.yml
    with open('user_input.yml', 'r') as f:
        user_input = yaml.safe_load(f)
        
    if 'kubernetes_deployment' not in user_input:
        print("Error: kubernetes_deployment section not found in user_input.yml", file=sys.stderr)
        sys.exit(1)

    # Validate addresses before proceeding
    if not validate_addresses(user_input['kubernetes_deployment']):
        print("Error: Please replace all IP placeholders in user_input.yml", file=sys.stderr)
        sys.exit(1)

    # Read the template
    template_path = os.path.join('templates', 'inventory.ini.j2')
    if not os.path.exists(template_path):
        print(f"Error: Template file not found at {template_path}", file=sys.stderr)
        sys.exit(1)

    # Setup Jinja2 environment
    env = Environment(loader=FileSystemLoader('templates'))
    template = env.get_template('inventory.ini.j2')

    # Process nodes to ensure they have private_ip
    def process_nodes(nodes):
        processed = []
        for node in nodes:
            node_copy = node.copy()
            if 'private_ip' not in node_copy:
                print(f"Warning: private_ip not found for node {node_copy['name']}, using ansible_host as private_ip", file=sys.stderr)
                node_copy['private_ip'] = node_copy['ansible_host']
            processed.append(node_copy)
        return processed

    # Get node configurations
    control_plane_nodes = process_nodes(user_input['kubernetes_deployment']['control_plane_nodes'])
    worker_nodes = process_nodes(user_input['kubernetes_deployment'].get('worker_nodes', []))

    # Format SSL addresses
    ssl_addresses = format_ssl_addresses(
        user_input['kubernetes_deployment'],
        control_plane_nodes,
        worker_nodes
    )

    # Prepare template variables
    template_vars = {
        'control_plane_nodes': control_plane_nodes,
        'worker_nodes': worker_nodes,
        'ssh_key_path': os.path.expanduser(user_input['kubernetes_deployment']['ssh_key_path']),
        'default_ansible_user': user_input['kubernetes_deployment']['default_ansible_user'],
        'kubernetes_deployment': user_input['kubernetes_deployment'],
        'supplementary_ssl_addresses': ssl_addresses
    }

    # Write inventory file
    os.makedirs('inventory/kubespray', exist_ok=True)
    inventory_content = template.render(**template_vars)
    inventory_path = 'inventory/kubespray/inventory.ini'
    with open(inventory_path, 'w') as f:
        f.write(inventory_content)

    # Verify the generated inventory
    if not verify_inventory(inventory_path):
        print("Error: Invalid inventory generated. Please check the configuration.", file=sys.stderr)
        sys.exit(1)

    print("\nSuccessfully generated inventory file.")
    print(f"\nInventory file location: {os.path.abspath(inventory_path)}")
    print("\nGenerated inventory content:")
    print("=" * 80)
    print(inventory_content)
    print("=" * 80)

    # Add wait time for reading inventory
    print("\nWaiting 5 seconds for inventory review...")
    import time
    time.sleep(5)

    # Print nodes for verification
    print("\nControl Plane Nodes:")
    for node in template_vars['control_plane_nodes']:
        user = node.get('ansible_user', template_vars['default_ansible_user'])
        print(f"  - {node['name']}: Public IP: {node['ansible_host']}, Private IP: {node['private_ip']} (user: {user})")

    if template_vars['worker_nodes']:
        print("\nWorker Nodes:")
        for node in template_vars['worker_nodes']:
            user = node.get('ansible_user', template_vars['default_ansible_user'])
            print(f"  - {node['name']}: Public IP: {node['ansible_host']}, Private IP: {node['private_ip']} (user: {user})")

    print("\nSupplementary SSL Addresses:")
    for addr in ssl_addresses:
        print(f"  - {addr}")

except FileNotFoundError as e:
    print(f"Error: File not found - {str(e)}", file=sys.stderr)
    sys.exit(1)
except yaml.YAMLError as e:
    print(f"Error parsing YAML: {str(e)}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'Error: {str(e)}', file=sys.stderr)
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
    log_error "Failed to generate inventory file."
    exit 1
fi

log_success "Inventory file generated successfully"

# Test SSH connectivity to all nodes
log_section "SSH CONNECTIVITY TEST"
log_info "Testing SSH connectivity to all nodes..."
python3 << EOF
import yaml
import subprocess
import sys
import os

def test_ssh_connection(host, user, key_path):
    cmd = f"ssh -i {key_path} -o StrictHostKeyChecking=no -o ConnectTimeout=10 {user}@{host} 'echo SSH connection successful'"
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.returncode == 0, result.stdout if result.returncode == 0 else result.stderr
    except Exception as e:
        return False, str(e)

try:
    with open('user_input.yml', 'r') as f:
        config = yaml.safe_load(f)

    ssh_key_path = os.path.expanduser(config['kubernetes_deployment']['ssh_key_path'])
    default_user = config['kubernetes_deployment']['default_ansible_user']

    all_nodes = config['kubernetes_deployment']['control_plane_nodes']
    if 'worker_nodes' in config['kubernetes_deployment']:
        all_nodes.extend(config['kubernetes_deployment']['worker_nodes'])

    print("\nTesting SSH connections:")
    all_successful = True
    for node in all_nodes:
        user = node.get('ansible_user', default_user)
        success, output = test_ssh_connection(node['ansible_host'], user, ssh_key_path)
        status = "✓" if success else "✗"
        print(f"  {status} {node['name']} ({user}@{node['ansible_host']})")
        if not success:
            print(f"    Error: {output.strip()}")
            all_successful = False

    if not all_successful:
        print("\nSome SSH connections failed. Please check your SSH configuration.", file=sys.stderr)
        sys.exit(1)

except Exception as e:
    print(f"Error testing SSH connections: {str(e)}", file=sys.stderr)
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
    log_error "SSH connectivity test failed"
    exit 1
fi

log_success "SSH connectivity test successful"
log_success "Kubernetes setup preparation completed successfully"

# Check if ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    log_error "ansible-playbook command not found. Please install Ansible first."
    exit 1
fi

# Run the Ansible playbook
log_section "ANSIBLE PLAYBOOK EXECUTION"
log_success "Starting Ansible playbook execution"
log "Logs will be saved to:"
log "  • Full deployment log: ${LOG_FILE}"
log "  • Ansible output log: ${ANSIBLE_OUTPUT_LOG}"
log "  • Async tasks log: ${ASYNC_LOG}"

# Create async logs directory
mkdir -p "${LOG_DIR}/async"
chmod 755 "${LOG_DIR}/async"

# Function to monitor async task progress
monitor_async_progress() {
    local async_dir="$1"
    local last_check=0
    local poll_interval=5  # Check every 5 seconds
    local last_progress=""

    while true; do
        current_time=$(date +%s)
        # Only check if enough time has passed
        if (( current_time - last_check >= poll_interval )); then
            last_check=$current_time
            timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            
            # Check Kubespray progress from ansible output
            if [ -f "$ANSIBLE_PIPE" ]; then
                # Look for specific Kubespray stages
                local current_stage=$(tail -n 50 "$ANSIBLE_PIPE" 2>/dev/null | grep -E "TASK \[.*\]" | tail -n 1)
                if [ ! -z "$current_stage" ] && [ "$current_stage" != "$last_progress" ]; then
                    echo -e "${timestamp} | Current Stage: $current_stage" | tee -a "${ASYNC_LOG}"
                    last_progress="$current_stage"
                fi
            fi
            
            # Check all async files
            for async_file in "${async_dir}"/*; do
                if [ -f "$async_file" ]; then
                    local task_name=$(basename "$async_file")
                    
                    # Extract and display progress information
                    if grep -q "finished:" "$async_file" 2>/dev/null; then
                        echo -e "${timestamp} | Task completed: ${task_name}" | tee -a "${ASYNC_LOG}"
                        continue
                    fi
                    
                    # Check for specific Kubespray progress indicators
                    local kubespray_output=$(grep -A 5 "stdout:" "$async_file" 2>/dev/null)
                    if [ ! -z "$kubespray_output" ]; then
                        # Extract meaningful progress information
                        echo "$kubespray_output" | while IFS= read -r line; do
                            if [[ "$line" =~ "PLAY RECAP" ]]; then
                                echo -e "${timestamp} | Task ${task_name}: Kubespray deployment completed" | tee -a "${ASYNC_LOG}"
                                break 2
                            elif [[ "$line" =~ "TASK" ]] || [[ "$line" =~ "RUNNING" ]] || [[ "$line" =~ "PLAY" ]]; then
                                if [ "$line" != "$last_progress" ]; then
                                    echo -e "${timestamp} | Task ${task_name}: $line" | tee -a "${ASYNC_LOG}"
                                    last_progress="$line"
                                fi
                            elif [[ "$line" =~ "failed=" ]] || [[ "$line" =~ "error" ]]; then
                                echo -e "${timestamp} | Task ${task_name} Warning: $line" | tee -a "${ASYNC_LOG}"
                            fi
                        done
                    fi
                fi
            done

            # Display periodic heartbeat to show monitoring is active
            echo -e "${timestamp} | Still monitoring deployment progress..." | tee -a "${ASYNC_LOG}"
        fi
        sleep 1
    done
}

# Set environment variables for Ansible
export ANSIBLE_FORCE_COLOR=true
export ANSIBLE_ASYNC_DIR="${LOG_DIR}/async"
export ANSIBLE_KEEP_REMOTE_FILES=1

# Create named pipes for output handling
PIPE_DIR=$(mktemp -d)
ANSIBLE_PIPE="${PIPE_DIR}/ansible_pipe"
MONITOR_PIPE="${PIPE_DIR}/monitor_pipe"

# Create the pipes with proper permissions
mkfifo -m 600 "$ANSIBLE_PIPE"
mkfifo -m 600 "$MONITOR_PIPE"

# Ensure log files exist before redirecting output
touch "${ANSIBLE_OUTPUT_LOG}"
touch "${ASYNC_LOG}"

# Start the monitoring in background
monitor_async_progress "${LOG_DIR}/async" > "$MONITOR_PIPE" &
MONITOR_PID=$!

# Run ansible-playbook with output redirection
ansible-playbook kubernetes.yml -i inventory/kubespray/inventory.ini -vvvv 2>&1 | tee "${ANSIBLE_PIPE}" &
ANSIBLE_PID=$!

# Process both outputs
(
    # Use a subshell to handle the output processing
    while IFS= read -r line; do
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[${timestamp}] ${line}" | tee -a "${ANSIBLE_OUTPUT_LOG}"
    done < <(cat "$ANSIBLE_PIPE" & cat "$MONITOR_PIPE")
) &
OUTPUT_PID=$!

# Wait for ansible-playbook to complete
wait $ANSIBLE_PID
ANSIBLE_EXIT_CODE=$?

# Clean up
kill $MONITOR_PID $OUTPUT_PID 2>/dev/null
wait $OUTPUT_PID 2>/dev/null
rm -f "$ANSIBLE_PIPE" "$MONITOR_PIPE"
rmdir "$PIPE_DIR"

# Check ansible exit code
if [ $ANSIBLE_EXIT_CODE -ne 0 ]; then
    log_section "DEPLOYMENT FAILURE"
    log_error "Kubernetes deployment failed with exit code: ${ANSIBLE_EXIT_CODE}"
    log_error "Please check the error messages above and in the following logs:"
    log_info "  • Full deployment log: ${LOG_FILE}"
    log_info "  • Ansible output log: ${ANSIBLE_OUTPUT_LOG}"
    log_info "  • Async tasks log: ${ASYNC_LOG}"
    log_end
    exit 1
fi

log_section "DEPLOYMENT SUCCESS"
log_success "Kubernetes deployment completed successfully!"

# Display post-deployment information
log_section "POST-DEPLOYMENT INFORMATION"
log_success "You can now verify the cluster status using:"
log_info "  • kubectl get nodes"
log_info "  • kubectl cluster-info"
log_info "  • kubectl get pods --all-namespaces"

log_end

log_success "Deployment logs are available at:"
log_info "  • Full deployment log: ${LOG_FILE}"
log_info "  • Ansible output log: ${ANSIBLE_OUTPUT_LOG}"
log_info "  • Async tasks log: ${ASYNC_LOG}"

# Add trap for script exit
trap 'log_section "SCRIPT EXIT"; log_info "Script exited with status $?"; echo "=== Script ended at $(date "+%Y-%m-%d %H:%M:%S") ===" >> "${LOG_FILE}"' EXIT 