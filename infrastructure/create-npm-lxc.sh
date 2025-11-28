#!/bin/bash

# Proxmox LXC Deployment Script
# Creates an Nginx Proxy Manager LXC container with options for network and storage.
# Idempotent and non-interactive for automation.

# --- Configuration Variables ---
CT_ID=1018
HOSTNAME="tan-npm"
TEMPLATE="local:vztmpl/ubuntu-24.04-standard_24.04-1_amd64.tar.zst"
CORES=2
MEMORY=2048
SWAP=512

# NPM Version Control
# Set to "latest" to fetch from GitHub, or specific tag like "2.13.4"
NPM_VERSION="latest"
# Fallback version if "latest" cannot be fetched (e.g. GitHub API down)
NPM_FALLBACK="2.13.4"

# Storage Configuration
# Default: Local LVM
STORAGE="local-lvm" 
DISK_SIZE="8G"

# Example: CIFS / Network Storage
# STORAGE="PMStor01-CIFS" 
# DISK_SIZE="8G"

UNPRIVILEGED=1
START_ON_BOOT=1
TAGS="community-script;proxy"

# Network Configuration
# 1 = DHCP, 0 = Static
DHCP=1
STATIC_IP="10.0.0.218/24"
GATEWAY="10.0.0.1"
BRIDGE="vmbr0"

# Mount Point Configuration
# Set to 1 to backup your NPM data to the host
MOUNT_ENABLED=0
MOUNT_HOST_PATH="/opt/data/npm"
MOUNT_CONTAINER_PATH="/data"

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

# Start Container
echo "Starting Container..."
pct start $CT_ID

# Post-Install Configuration
echo "Waiting 15s for boot..."
sleep 15

# --- Determine Version ---
if [ "$NPM_VERSION" == "latest" ]; then
    echo "Fetching latest Nginx Proxy Manager release..."
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/NginxProxyManager/nginx-proxy-manager/releases/latest | grep "tag_name" | cut -d'"' -f4)
    DETECTED_VERSION=${LATEST_RELEASE#v} # Strip 'v' prefix

    if [ -z "$DETECTED_VERSION" ]; then
        NPM_VERSION="$NPM_FALLBACK"
        echo "Warning: Could not fetch latest version. Fallback to v$NPM_VERSION"
    else
        NPM_VERSION="$DETECTED_VERSION"
    fi
else
    echo "Using specified version: v$NPM_VERSION"
fi

echo "Installing Nginx Proxy Manager v$NPM_VERSION..."

# Install Prerequisites
pct exec $CT_ID -- bash -c "apt-get update && apt-get install -y curl gnupg ca-certificates git build-essential python3 python3-dev certbot sqlite3 openssl"

# Install Node.js 22
pct exec $CT_ID -- bash -c "curl -fsSL https://deb.nodesource.com/setup_22.x | bash -"
pct exec $CT_ID -- bash -c "apt-get install -y nodejs && npm install -g yarn"

# Install OpenResty (Nginx fork)
pct exec $CT_ID -- bash -c "curl -fsSL https://openresty.org/package/pubkey.gpg | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/openresty.gpg"
pct exec $CT_ID -- bash -c "echo 'deb http://openresty.org/package/debian bookworm openresty' | tee /etc/apt/sources.list.d/openresty.sources"
pct exec $CT_ID -- bash -c "apt-get update && apt-get install -y openresty"

# Prepare Directories & Config
pct exec $CT_ID -- bash -c "mkdir -p /opt/nginxproxymanager /var/www/html /etc/nginx/logs /tmp/nginx/body /data/nginx/default_host /data/logs /data/access /data/custom_ssl"
pct exec $CT_ID -- bash -c "chmod -R 777 /var/cache/nginx && chown root /tmp/nginx"

# Compile & Install NPM (Using internal build script that mirrors community script logic)
# We pass the version ($NPM_VERSION) as the first argument to this script
cat << 'EOF' > /tmp/npm_build_script.sh
#!/bin/bash
set -e
RELEASE="$1" # Receive version from host script

if [ -z "$RELEASE" ]; then
    echo "Error: No version passed to build script."
    exit 1
fi

# 1. Download Source
cd /opt/nginxproxymanager
curl -fsSL https://github.com/NginxProxyManager/nginx-proxy-manager/tarball/v${RELEASE} | tar xz --strip-components=1

# 2. Set Version in Package.json
sed -i "s|\"version\": \"2.0.0\"|\"version\": \"$RELEASE\"|" /opt/nginxproxymanager/backend/package.json
sed -i "s|\"version\": \"2.0.0\"|\"version\": \"$RELEASE\"|" /opt/nginxproxymanager/frontend/package.json

# 3. Configure Nginx Environment
ln -sf /usr/bin/python3 /usr/bin/python
ln -sf /usr/local/openresty/nginx/sbin/nginx /usr/sbin/nginx
ln -sf /usr/local/openresty/nginx/ /etc/nginx

# Fix Nginx Configs
sed -i 's+^daemon+#daemon+g' /opt/nginxproxymanager/docker/rootfs/etc/nginx/nginx.conf
NGINX_CONFS=$(find /opt/nginxproxymanager -type f -name "*.conf")
for NGINX_CONF in $NGINX_CONFS; do
  sed -i 's+include conf.d+include /etc/nginx/conf.d+g' "$NGINX_CONF"
done

# Copy Default Configs
cp -r /opt/nginxproxymanager/docker/rootfs/var/www/html/* /var/www/html/
cp -r /opt/nginxproxymanager/docker/rootfs/etc/nginx/* /etc/nginx/
cp /opt/nginxproxymanager/docker/rootfs/etc/letsencrypt.ini /etc/letsencrypt.ini
cp /opt/nginxproxymanager/docker/rootfs/etc/logrotate.d/nginx-proxy-manager /etc/logrotate.d/nginx-proxy-manager
ln -sf /etc/nginx/nginx.conf /etc/nginx/conf/nginx.conf
rm -f /etc/nginx/conf.d/dev.conf

# Create Resolvers
echo resolver "$(awk 'BEGIN{ORS=" "} $1=="nameserver" {print ($2 ~ ":")? "["$2"]": $2}' /etc/resolv.conf);" >/etc/nginx/conf.d/include/resolvers.conf

# 4. Generate Dummy Certificate
if [ ! -f /data/nginx/dummycert.pem ]; then
  openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/O=Nginx Proxy Manager/OU=Dummy Certificate/CN=localhost" \
    -keyout /data/nginx/dummykey.pem \
    -out /data/nginx/dummycert.pem
fi

# 5. Setup /app Directory
mkdir -p /app/frontend/images
cp -r /opt/nginxproxymanager/backend/* /app

# 6. Frontend Build
export NODE_OPTIONS="--max_old_space_size=2048 --openssl-legacy-provider"
cd /opt/nginxproxymanager/frontend
sed -E -i 's/"node-sass" *: *"([^"]*)"/"sass": "\1"/g' package.json
yarn install --network-timeout 600000
yarn build
cp -r /opt/nginxproxymanager/frontend/dist/* /app/frontend
cp -r /opt/nginxproxymanager/frontend/public/images/* /app/frontend/images

# 7. Backend Setup
rm -rf /app/config/default.json
if [ ! -f /app/config/production.json ]; then
cat <<JSON > /app/config/production.json
{
  "database": {
    "engine": "knex-native",
    "knex": {
      "client": "sqlite3",
      "connection": {
        "filename": "/data/database.sqlite"
      }
    }
  }
}
JSON
fi

cd /app
yarn install --network-timeout 600000

# 8. Final Fixes
sed -i 's/user npm/user root/g; s/^pid/#pid/g' /usr/local/openresty/nginx/conf/nginx.conf
sed -r -i 's/^([[:space:]]*)su npm npm/\1#su npm npm/g;' /etc/logrotate.d/nginx-proxy-manager
EOF

# Push and Execute Build Script with Version Argument
pct push $CT_ID /tmp/npm_build_script.sh /tmp/npm_build_script.sh
pct exec $CT_ID -- bash /tmp/npm_build_script.sh "$NPM_VERSION"
pct exec $CT_ID -- rm /tmp/npm_build_script.sh

# Configure Systemd Service
cat << 'EOF' > /tmp/npm.service
[Unit]
Description=Nginx Proxy Manager
After=network.target openresty.service
[Service]
Type=simple
User=root
WorkingDirectory=/app
ExecStart=/usr/bin/node index.js
Restart=always
Environment=NODE_ENV=production
[Install]
WantedBy=multi-user.target
EOF

pct push $CT_ID /tmp/npm.service /etc/systemd/system/npm.service

# Finalize Services
pct exec $CT_ID -- bash -c "systemctl daemon-reload"
pct exec $CT_ID -- bash -c "systemctl enable openresty npm"
pct exec $CT_ID -- bash -c "systemctl start openresty npm"

echo "Nginx Proxy Manager v$NPM_VERSION Installation Complete."

if [ "$DHCP" -eq 1 ]; then
    echo "Access NPM at: http://(ContainerIP):81"
else
    echo "Access NPM at: http://${STATIC_IP%%/*}:81"
fi
echo "Default Login: admin@example.com / changeme"
