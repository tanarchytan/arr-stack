#!/bin/bash

# Proxmox LXC Deployment Script - Wrapper for Community Helper
# Wraps the official tteck/community-scripts installer for Plex Media Server.
# This ensures maximum compatibility and successful installation.

echo "======================================================="
echo "   Starting Plex Media Server Deployment via Helper    "
echo "======================================================="
echo ""
echo "This script will launch the interactive installer."
echo "Please follow the on-screen prompts."
echo ""

# Execute the official community script
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/plex.sh)"
