#!/bin/bash

# Proxmox LXC Deployment Script
# Creates a Plex LXC container with options for network, storage, and iGPU passthrough.
# Idempotent and non-interactive for automation.

# --- Configuration Variables ---
CT_ID=1017
HOSTNAME="tan-plex"
TEMPLATE="local:vztmpl/ubuntu-24.04-standard_24.04-1_amd64.tar.zst"
CORES=4
MEMORY=4096
SWAP=512

# Storage Configuration
# Default: Local LVM
STORAGE="local-lvm" 
DISK_SIZE="10G"

# Example: CIFS / Network Storage
# STORAGE="PMStor01-CIFS" 
# DISK_SIZE="10G"

UNPRIVILEGED=1
START_ON_BOOT=1
TAGS="community-script;media"

# Network Configuration
# 1 = DHCP, 0 = Static
DHCP=1
STATIC_IP="10.0.0.215/24"
GATEWAY="10.0.0.1"
BRIDGE="vmbr0"

# Mount Point Configuration
MOUNT_ENABLED=1
MOUNT_HOST_PATH="/mnt/arrdata"
MOUNT_CONTAINER_PATH="/data"

# iGPU Passthrough Configuration
IGPU_ENABLED=1
RENDER_GID=104
VIDEO_GID=44

# --- Main Script ---

# Check if container exists
if pct status $CT_ID >/dev/null 2>&1; then
    echo "LXC $CT_ID ($HOSTNAME) already exists. Skipping."
    exit 0
fi

echo "Starting creation of LXC $CT_ID ($HOSTNAME)..."

# Ensure Template Exists
TEMPLATE_FILE=$(basename "$TEMPLATE")
STORAGE_ID=$(echo "$TEMPLATE" | cut -d':' -f1)

echo "Checking template: $TEMPLATE_FILE..."
pveam update
pveam download "$STORAGE_ID" "$TEMPLATE_FILE" || echo "Template download skipped/failed (check existence)."

# Construct Network Configuration
if [ "$DHCP" -eq 1 ]; then
    echo "Network Mode: DHCP"
    NET_CONFIG="name=eth0,bridge=$BRIDGE,ip=dhcp,ip6=auto,type=veth"
else
    echo "Network Mode: Static IP ($STATIC_IP)"
    NET_CONFIG="name=eth0,bridge=$BRIDGE,ip=$STATIC_IP,gw=$GATEWAY,type=veth"
fi

# Create Container
echo "Building Container on storage: $STORAGE..."
pct create $CT_ID "$TEMPLATE" \
    --hostname "$HOSTNAME" \
    --cores "$CORES" \
    --memory "$MEMORY" \
    --swap "$SWAP" \
    --storage "$STORAGE" \
    --rootfs volume="$STORAGE:$DISK_SIZE" \
    --net0 "$NET_CONFIG" \
    --unprivileged "$UNPRIVILEGED" \
    --features keyctl=1,nesting=1,mount=nfs \
    --tags "$TAGS" \
    --onboot "$START_ON_BOOT"

if [ $? -eq 0 ]; then
    echo "Container created successfully."
else
    echo "Error creating container."
    exit 1
fi

CONFIG_FILE="/etc/pve/lxc/$CT_ID.conf"

# Configure Bind Mount
if [ "$MOUNT_ENABLED" -eq 1 ]; then
    echo "Configuring Bind Mount..."
    
    if [ ! -d "$MOUNT_HOST_PATH" ]; then
        echo "Warning: Host path $MOUNT_HOST_PATH does not exist. Creating it."
        mkdir -p "$MOUNT_HOST_PATH"
    fi

    if ! grep -q "mp0:" "$CONFIG_FILE"; then
        echo "mp0: $MOUNT_HOST_PATH,mp=$MOUNT_CONTAINER_PATH" >> "$CONFIG_FILE"
        echo "Mount added: $MOUNT_HOST_PATH -> $MOUNT_CONTAINER_PATH"
    else
        echo "Mount point 'mp0' already exists."
    fi
fi

# Configure iGPU Passthrough
if [ "$IGPU_ENABLED" -eq 1 ]; then
    echo "Configuring iGPU Passthrough..."
    
    if [ -e "/dev/dri/card1" ] && [ -e "/dev/dri/renderD128" ]; then
        if ! grep -q "dev0:" "$CONFIG_FILE"; then
            echo "dev0: /dev/dri/card1,gid=$VIDEO_GID" >> "$CONFIG_FILE"
            echo "dev1: /dev/dri/renderD128,gid=$RENDER_GID" >> "$CONFIG_FILE"
            echo "iGPU Passthrough configured."
        else
            echo "iGPU config already exists."
        fi
    else
        echo "Host missing /dev/dri devices. Skipping iGPU config."
    fi
fi

# Start Container
echo "Starting Container..."
pct start $CT_ID

# Post-Install Configuration
echo "Waiting 15s for boot..."
sleep 15

echo "Installing Plex Media Server..."

# Install Prerequisites
pct exec $CT_ID -- bash -c "apt-get update && apt-get install -y curl gnupg ca-certificates"

# Add Plex Repository
pct exec $CT_ID -- bash -c "echo 'deb https://downloads.plex.tv/repo/deb public main' | tee /etc/apt/sources.list.d/plexmediaserver.list"
pct exec $CT_ID -- bash -c "curl https://downloads.plex.tv/plex-keys/PlexSign.key | apt-key add -"

# Install Package
pct exec $CT_ID -- bash -c "apt-get update && apt-get install -y plexmediaserver"

# Fix iGPU Permissions
if [ "$IGPU_ENABLED" -eq 1 ]; then
    echo "Setting container iGPU permissions..."
    pct exec $CT_ID -- bash -c "groupadd -g $VIDEO_GID video || true"
    pct exec $CT_ID -- bash -c "groupadd -g $RENDER_GID render || true"
    pct exec $CT_ID -- bash -c "usermod -aG video,render plex"
fi

echo "Plex Installation Complete."

if [ "$DHCP" -eq 1 ]; then
    echo "Access Plex at: http://(ContainerIP):32400/web"
else
    echo "Access Plex at: http://${STATIC_IP%%/*}:32400/web"
fi
