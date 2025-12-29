#!/bin/bash

# ==============================================================================
# AWX & Ansible Installation Script for Ubuntu (AWS EC2)
# ==============================================================================
# This script installs:
# 1. System prerequisites
# 2. Ansible (latest via PPA)
# 3. Docker (Community Edition)
# 4. K3s (Lightweight Kubernetes)
# 5. AWX Operator
# 6. AWX Instance (exposed via NodePort/Ingress)
# ==============================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

function success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 1. Update System & Install Prerequisites
log "Updating system and installing prerequisites..."
sudo apt-get update -y
sudo apt-get install -y curl wget git jq build-essential software-properties-common

# 2. Install Ansible
log "Installing Ansible..."
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt-get install -y ansible
success "Ansible installed successfully."

# 3. Install Docker (Optional but often useful alongside AWX)
log "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    success "Docker installed."
else
    log "Docker already installed, skipping."
fi

# 4. Install K3s
log "Installing K3s..."
if ! command -v k3s &> /dev/null; then
    curl -sfL https://get.k3s.io | sh -
    # Allow current user to read kubeconfig if needed (though we use sudo mostly)
    sudo chmod 644 /etc/rancher/k3s/k3s.yaml
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    success "K3s installed."
else
    log "K3s already installed, skipping."
fi

# Helper for kubectl
alias kubectl='sudo k3s kubectl'

# 5. Install AWX Operator
log "Setting up AWX Operator..."
# Create awx namespace
sudo k3s kubectl create namespace awx --dry-run=client -o yaml | sudo k3s kubectl apply -f -

# Switch to awx namespace context isn't really needed if we specify -n, but let's set it in config for convenience if possible,
# or just stick to -n awx.

# Install the operator manifest
# Using the latest stable version 2.19.1 as reference, or checking latest
AWX_OPERATOR_VERSION="2.19.1" 
log "Deploying AWX Operator version $AWX_OPERATOR_VERSION..."
sudo k3s kubectl apply -k "github.com/ansible/awx-operator/config/default?ref=${AWX_OPERATOR_VERSION}"

log "Waiting for AWX Operator to be ready (this may take a minute)..."
sudo k3s kubectl wait --for=condition=Ready pods --all -n awx --timeout=300s || {
    echo "Timeout waiting for operator pods. Creating anyway, but check logs."
}

# 6. Deploy AWX Instance
log "Deploying AWX instance..."
cat <<EOF | sudo k3s kubectl apply -f -
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-demo
  namespace: awx
spec:
  service_type: NodePort
  ingress_type: Ingress
  hostname: awx.local
  admin_user: admin
  nodeport_port: 30080
EOF

# Note: nodeport_port is a handy way to force a specific port if supported (check CRD docs). 
# If 'nodeport_port' isn't supported in this specific CR version, it might be ignored, 
# but service_type: NodePort will definitely allocate a high port.
# Let's also create a direct Ingress for easier access on port 80 if K3s Traefik is running.

log "Configuring Ingress for external access..."
cat <<EOF | sudo k3s kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: awx-ingress
  namespace: awx
  annotations:
    nomad/ingress: "true"
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: awx-demo-service
            port:
              number: 80
EOF

success "Installation commands submitted."
echo "--------------------------------------------------------"
echo "Installation is proceeding in the background."
echo "To check status, run: sudo k3s kubectl get pods -n awx --watch"
echo "--------------------------------------------------------"
echo "Once the 'awx-demo' pod is RUNNING:"
echo "1. Access AWX at: http://<YOUR-SERVER-IP>"
echo "2. Get the Admin Password with:"
echo "   sudo k3s kubectl get secret awx-demo-admin-password -n awx -o jsonpath='{.data.password}' | base64 --decode; echo"
echo "--------------------------------------------------------"
