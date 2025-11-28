#!/bin/bash

# Proxmox Host iGPU Enablement Script
# Configures GRUB and Kernel Modules for Intel iGPU Passthrough/GVT-g.
# Requires reboot to take effect.

# --- Configuration ---
# Intel iGPU kernel parameters
GRUB_CMD_ADD="intel_iommu=on i915.enable_gvt=1"
MODULES_TO_ADD=("kvmgt" "vfio-iommu-type1" "vfio-mdev")

# --- Main Script ---

echo "Configuring Proxmox Host for Intel iGPU..."

# 1. Configure GRUB
GRUB_FILE="/etc/default/grub"
if [ -f "$GRUB_FILE" ]; then
    CURRENT_CMD=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE" | cut -d'"' -f2)
    
    if [[ "$CURRENT_CMD" != *"$GRUB_CMD_ADD"* ]]; then
        echo "Updating GRUB config..."
        # Backup
        cp "$GRUB_FILE" "${GRUB_FILE}.bak"
        
        # Append settings to GRUB_CMDLINE_LINUX_DEFAULT
        sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $GRUB_CMD_ADD\"/" "$GRUB_FILE"
        
        echo "Running update-grub..."
        update-grub
        echo "GRUB updated. Reboot required."
    else
        echo "GRUB already configured for iGPU."
    fi
else
    echo "Error: $GRUB_FILE not found (Are you running this on Proxmox?)"
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

# 3. Verify Device Existence (Only works if already rebooted)
if [ -e "/dev/dri/card0" ] || [ -e "/dev/dri/renderD128" ]; then
    echo "iGPU devices detected on host."
else
    echo "Warning: /dev/dri devices not found. A reboot is likely needed."
fi

echo "Host configuration complete."
