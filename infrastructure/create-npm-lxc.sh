#!/bin/bash

# Proxmox LXC Deployment Script - Wrapper for Community Helper
# Wraps the official tteck/community-scripts installer for Nginx Proxy Manager.
# This ensures maximum compatibility and successful installation.

echo "======================================================="
echo "   Starting Nginx Proxy Manager Deployment via Helper  "
echo "======================================================="
echo ""
echo "This script will launch the interactive installer."
echo "Please follow the on-screen prompts."
echo ""

# Execute the official community script
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/nginxproxymanager.sh)"

