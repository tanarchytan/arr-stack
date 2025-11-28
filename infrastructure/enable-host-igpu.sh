#!/bin/bash

# Proxmox Host iGPU Enablement Script
# Configures GRUB and Kernel Modules for Intel iGPU Passthrough/GVT-g.
# Optimized for headless servers (disables framebuffers).
# Requires reboot to take effect.

# --- Configuration ---
# Full optimized command line for headless Plex transcoding
# Includes passthrough mode and disables host display drivers to free up the GPU
GRUB_CMD_TARGET="quiet intel_iommu=on i915.enable_gvt=1 iommu=pt video=efifb:off video=vesafb:off"

MODULES_TO_ADD=("kvmgt" "vfio-iommu-type1" "vfio-mdev")

# --- Main Script ---

echo "Configuring Proxmox Host for Intel iGPU..."

# 1. Configure GRUB
GRUB_FILE="/etc/default/grub"
if [ -f "$GRUB_FILE" ]; then
    # Read current default line (stripping quotes)
    CURRENT_CMD=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE" | cut -d'"' -f2)
    
    # Check if our target settings are present. 
    # Simple check: if it doesn't contain our key flags, we update.
    # Using a loose check for key components to avoid constant overwrites if order differs.
    if [[ "$CURRENT_CMD" != *"intel_iommu=on"* ]] || [[ "$CURRENT_CMD" != *"i915.enable_gvt=1"* ]]; then
        echo "Updating GRUB config..."
        cp "$GRUB_FILE" "${GRUB_FILE}.bak"
        
        # Replace the line entirely with our optimized version
        sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMD_TARGET\"|" "$GRUB_FILE"
        
        echo "Running update-grub..."
        update-grub
        echo "GRUB updated. Reboot required."
    else
        echo "GRUB already configured for iGPU."
    fi
else
    echo "Error: $GRUB_FILE not found."
    exit 1
fi

# 2. Configure Kernel Modules
MODULES_FILE="/etc/modules"
CHANGED=0

echo "Checking kernel modules..."
for mod in "${MODULES_TO_ADD[@]}"; do
    if ! grep -q "^$mod" "$MODULES_FILE"; then
        echo "Adding module: $mod"
        echo "$mod" >> "$MODULES_FILE"
        CHANGED=1
    else
        echo "Module $mod already present."
    fi
done

if [ $CHANGED -eq 1 ]; then
    echo "Kernel modules updated. Reboot required."
else
    echo "Kernel modules already configured."
fi

# 3. Verify Device Existence
if [ -e "/dev/dri/card0" ] || [ -e "/dev/dri/renderD128" ]; then
    echo "iGPU devices detected on host."
else
    echo "Warning: /dev/dri devices not found. A reboot is likely needed."
fi

echo "Host configuration complete."
