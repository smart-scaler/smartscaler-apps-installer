#!/bin/bash

# ============================================================================
# Credential Setup Script for Smart Scaler Apps Installer
# ============================================================================
# This script helps you set the required credentials as environment variables
# Run with: source ./set-credentials.sh  (note the 'source' command)
# ============================================================================

echo "🔐 Smart Scaler Apps Installer - Credential Setup"
echo "=================================================="
echo ""

# Check if running with source
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "⚠️  WARNING: Run this script with 'source' to export variables to your shell:"
    echo "   source ./set-credentials.sh"
    echo ""
    echo "   Or set the variables manually and run the script normally for validation only."
    echo ""
fi

# Function to securely read password
read_password() {
    local prompt="$1"
    local var_name="$2"
    echo -n "$prompt"
    read -s password
    echo ""
    export "$var_name"="$password"
    echo "✅ $var_name set (hidden)"
}

# Function to read normal input
read_input() {
    local prompt="$1" 
    local var_name="$2"
    echo -n "$prompt"
    read input
    export "$var_name"="$input"
    echo "✅ $var_name set to: $input"
}

echo "📋 Please provide the following credentials:"
echo ""

# NGC Credentials
echo "🔹 NGC (NVIDIA GPU Cloud) Credentials:"
echo "   Get these from: https://catalog.ngc.nvidia.com/"
echo ""

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    read_input "   NGC API Key: " "NGC_API_KEY"
    read_input "   NGC Docker API Key: " "NGC_DOCKER_API_KEY"
    echo ""

    # Avesha Credentials  
    echo "🔹 Avesha Docker Registry Credentials:"
    echo "   Contact Avesha support if you don't have these"
    echo ""
    read_input "   Avesha Username: " "AVESHA_DOCKER_USERNAME"
    read_password "   Avesha Password: " "AVESHA_DOCKER_PASSWORD"
    echo ""

    echo "✅ All credentials have been set as environment variables!"
    echo ""
    echo "🚀 You can now run your deployment:"
    echo "   ansible-playbook microk8s.yml"
    echo ""
    echo "💡 To make these permanent, add them to your ~/.bashrc:"
    echo "   echo 'export NGC_API_KEY=\"$NGC_API_KEY\"' >> ~/.bashrc"
    echo "   echo 'export NGC_DOCKER_API_KEY=\"$NGC_DOCKER_API_KEY\"' >> ~/.bashrc"  
    echo "   echo 'export AVESHA_DOCKER_USERNAME=\"$AVESHA_DOCKER_USERNAME\"' >> ~/.bashrc"
    echo "   echo 'export AVESHA_DOCKER_PASSWORD=\"$AVESHA_DOCKER_PASSWORD\"' >> ~/.bashrc"
fi

# Validation section (always runs)
echo "🔍 Validating current environment variables..."
echo ""

missing_vars=0

check_var() {
    local var_name="$1"
    local var_value="${!var_name}"
    
    if [[ -z "$var_value" ]]; then
        echo "❌ $var_name: Not set"
        ((missing_vars++))
    else
        # Show first 8 characters for security
        local preview="${var_value:0:8}..."
        echo "✅ $var_name: $preview"
    fi
}

check_var "NGC_API_KEY"
check_var "NGC_DOCKER_API_KEY" 
check_var "AVESHA_DOCKER_USERNAME"
check_var "AVESHA_DOCKER_PASSWORD"

echo ""

if [[ $missing_vars -eq 0 ]]; then
    echo "🎉 All required credentials are set!"
    echo "   You can proceed with: ansible-playbook microk8s.yml"
else
    echo "⚠️  $missing_vars credential(s) missing."
    echo ""
    echo "📝 You have these options:"
    echo "   1. Run: source ./set-credentials.sh"  
    echo "   2. Set manually: export NGC_API_KEY=\"your-key\""
    echo "   3. Edit vault file: group_vars/all/vault.yml"
    echo "   4. Pass via command: ansible-playbook microk8s.yml -e ngc_api_key=your-key"
fi

echo ""
