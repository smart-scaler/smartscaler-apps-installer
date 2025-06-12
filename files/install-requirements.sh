#!/bin/bash

# Update package lists
apt-get update

# Install python3-pip and other required packages
apt-get install -y python3-pip python3-dev

# Install required Python packages
pip3 install ansible kubernetes openshift pyyaml

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

# Get the script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Install requirements
pip3 install -r "$PROJECT_ROOT/requirements.txt" 
