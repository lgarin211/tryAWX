#!/bin/bash
set -e

echo "Starting setup..."

# Install Ansible
echo "Installing Ansible..."
sudo apt-get update
sudo apt-get install -y software-properties-common pip
pip install ansible --break-system-packages
ansible --version

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install k3d
echo "Installing k3d..."
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install Kustomize (needed for AWX Operator)
echo "Installing Kustomize..."
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/

echo "Setup complete!"
