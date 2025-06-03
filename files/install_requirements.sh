#!/bin/bash

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

# Install system-wide pip if not present
if ! command -v pip3 &> /dev/null; then
    apt-get update
    apt-get install -y python3-pip
fi

# Get the script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Install requirements
pip3 install -r "$PROJECT_ROOT/requirements.txt" 