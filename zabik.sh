#!/bin/bash

# ==============================================================================
# Zabbix Server & Agent Installation Script for Ubuntu (AWS EC2)
# ==============================================================================
# This script installs:
# 1. Zabbix Repository (7.0 LTS)
# 2. MariaDB Database Server
# 3. Zabbix Server, Frontend, Agent
# 4. Configures Self-Monitoring
# ==============================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

function log() { echo -e "${BLUE}[INFO]${NC} $1"; }
function success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# 0. Check Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Generate a random password for Zabbix DB
DB_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')

log "Starting Zabbix Installation..."
log "Generated Database Password: $DB_PASSWORD"

# 1. Install Zabbix Repository
log "Installing Zabbix Repository (7.0 LTS)..."
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu$(lsb_release -rs)_all.deb -O zabbix-release.deb
dpkg -i zabbix-release.deb
apt-get update

# 2. Install Packages
log "Installing Zabbix Server, Frontend, Agent, and MariaDB..."
apt-get install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent mariadb-server

# 3. Configure Database
log "Configuring MariaDB..."
systemctl start mariadb
systemctl enable mariadb

# Create DB and User
mysql -e "create database zabbix character set utf8mb4 collate utf8mb4_bin;"
mysql -e "create user zabbix@localhost identified by '$DB_PASSWORD';"
mysql -e "grant all privileges on zabbix.* to zabbix@localhost;"
mysql -e "set global log_bin_trust_function_creators = 1;"

# Import Schema
log "Importing initial schema (this might take a moment)..."
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p"$DB_PASSWORD" zabbix

# Disable log_bin_trust_function_creators
mysql -e "set global log_bin_trust_function_creators = 0;"

# 4. Configure Zabbix Server
log "Configuring Zabbix Server..."
sed -i "s/# DBPassword=/DBPassword=$DB_PASSWORD/" /etc/zabbix/zabbix_server.conf

# 5. Configure Zabbix Agent (for Self-Monitoring)
log "Configuring Zabbix Agent..."
# Hostname=Zabbix server is the default in Zabbix frontend for the server itself
sed -i 's/Hostname=Zabbix server/Hostname=Zabbix server/' /etc/zabbix/zabbix_agentd.conf
# Ensure Server pointers are local
sed -i 's/^Server=127.0.0.1/Server=127.0.0.1/' /etc/zabbix/zabbix_agentd.conf
sed -i 's/^ServerActive=127.0.0.1/ServerActive=127.0.0.1/' /etc/zabbix/zabbix_agentd.conf

# 6. Restart Services
log "Restarting Zabbix Server, Agent and Apache..."
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2

# 7. Final Output
echo "=========================================================="
success "Zabbix Installation Complete!"
echo "=========================================================="
echo "1. Web Interface:   http://$(curl -s ifconfig.me)/zabbix"
echo "   (Ensure Port 80 is open in your Security Group)"
echo ""
echo "2. Database Details:"
echo "   - User:      zabbix"
echo "   - Password:  $DB_PASSWORD"
echo "   (You will need this password for the Web Installer setup)"
echo ""
echo "3. Default Login:"
echo "   - Username:  Admin"
echo "   - Password:  zabbix"
echo ""
echo "4. Self-Monitoring:"
echo "   - The Zabbix Agent is installed and pointing to localhost."
echo "   - Check 'Configuration -> Hosts' in the UI to confirm."
echo "=========================================================="
