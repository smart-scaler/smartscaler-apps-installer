#!/bin/bash

# Get the script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if we're in a virtual environment
if [ -z "$VIRTUAL_ENV" ]; then
    echo "Please activate a virtual environment first"
    exit 1
fi

# Install requirements using the virtual environment's pip
python -m pip install -r "$PROJECT_ROOT/requirements.txt"

# Ensure ansible is properly installed and available
python -m pip install --upgrade pip setuptools wheel
python -m pip install ansible-core==2.16.14 ansible==9.8.0

# Create ansible entry points
VENV_BIN="$VIRTUAL_ENV/bin"
cat > "$VENV_BIN/ansible" << 'EOF'
#!/bin/bash
VIRTUAL_ENV_DISABLE_PROMPT=1 source "$(dirname "$0")/activate"
python -m ansible.cli.adhoc "$@"
EOF

cat > "$VENV_BIN/ansible-playbook" << 'EOF'
#!/bin/bash
VIRTUAL_ENV_DISABLE_PROMPT=1 source "$(dirname "$0")/activate"
python -m ansible.cli.playbook "$@"
EOF

# Make the scripts executable
chmod +x "$VENV_BIN/ansible" "$VENV_BIN/ansible-playbook"

# Add virtual environment's bin to PATH if not already there
if [[ ":$PATH:" != *":$VIRTUAL_ENV/bin:"* ]]; then
    export PATH="$VIRTUAL_ENV/bin:$PATH"
fi

# Verify ansible installation
echo "Verifying Ansible installation..."
"$VENV_BIN/ansible" --version

# Print success message
echo "Installation complete. Please ensure your virtual environment is activated with:"
echo "source $VIRTUAL_ENV/bin/activate" 
