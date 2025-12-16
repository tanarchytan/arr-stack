# 🚀 Media Server Infrastructure (IaC)

![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Plex](https://img.shields.io/badge/Plex-E5A00D?style=for-the-badge&logo=plex&logoColor=white)

**Automated, version-controlled infrastructure for a self-hosted media server.**
This repository contains the `docker-compose` stacks, configuration templates, and Proxmox automation scripts to deploy a complete media stack with health monitoring, resource management, and a unified dashboard.

---

## 📂 Repository Structure

| Path | Description |
| :--- | :--- |
| **`media-server-stack/`** | Core Infrastructure (`Homepage`, `Dockge`) |
| **`media-download-stack/`** | VPN & Downloads (`Gluetun`, `qBittorrent`, `SABnzbd`) |
| **`media-content-stack/`** | Content Management (`Sonarr`, `Radarr`, `Lidarr`, `Prowlarr`, `Bazarr`, `Overseerr`) |
| **`infrastructure/`** | Proxmox Automation Scripts (`LXC creation`, `Host setup`) |
| **`config-templates/`** | Secure templates for `.env`, secrets, and Homepage configs |

---

## 🎯 Stack Components

### Media Server Stack (Infrastructure)
- **Homepage** - Unified dashboard with live service metrics and system monitoring
- **Dockge** - Docker stack management UI

### Media Download Stack
- **Gluetun** - VPN client with kill switch (ProtonVPN WireGuard)
- **qBittorrent** - Torrent client (routed through VPN)
- **SABnzbd** - Usenet client (routed through VPN)
- **Port Manager** - Automatic VPN port forwarding for qBittorrent

### Media Content Stack
- **Sonarr** - TV show management and automation
- **Radarr** - Movie management and automation
- **Lidarr** - Music management and automation
- **Bazarr** - Subtitle management
- **Prowlarr** - Indexer manager for *arr apps
- **Overseerr** - Media request management with Plex/Jellyfin integration

### Features
- ✅ **Health Checks**: All services have health monitoring
- ✅ **Resource Limits**: CPU and memory limits configured for stability
- ✅ **Dependency Management**: Services start in correct order
- ✅ **Centralized Logging**: Consistent log rotation across all services
- ✅ **Code-Based Configuration**: All settings managed via YAML files

---

## ⚡ Quick Start (Disaster Recovery)

Follow these steps to restore the entire stack from scratch on a fresh server.

### 1. Clone Repository
```
git clone https://github.com/yourusername/media-stack.git /opt/stacks
cd /opt/stacks
```

### 2. Restore Secrets
Copy the example templates and populate them with your real credentials.
```bash
# Gluetun VPN configuration
cp config-templates/env/gluetun.env.example media-download-stack/env/gluetun.env

# Homepage dashboard configuration
mkdir -p /opt/data/media/appdata/homepage
cp config-templates/homepage/*.yaml /opt/data/media/appdata/homepage/
cp config-templates/homepage/example.env /opt/data/media/appdata/homepage/.env
# Edit .env with your API keys
nano /opt/data/media/appdata/homepage/.env
```

### 3. Launch Stacks
Deploy all Docker services in the correct order.
```bash
# 1. Deploy core infrastructure (Homepage, Dockge)
docker compose -f media-server-stack/docker-compose.yml up -d

# 2. Deploy download stack (Gluetun, qBittorrent, SABnzbd)
docker compose -f media-download-stack/docker-compose.yml up -d

# 3. Deploy content management (Sonarr, Radarr, Overseerr, etc.)
docker compose -f media-content-stack/docker-compose.yml up -d

# 4. Access services
# Homepage Dashboard: http://your-server:3000
# Dockge: http://your-server:5001
# Overseerr: http://your-server:5055
```

---

## 🛠️ Infrastructure Automation (Proxmox)

This repository includes Infrastructure-as-Code (IaC) scripts to automate Proxmox resource creation.

### 1. Enable Host iGPU Passthrough
*Required for hardware transcoding in Plex.*

**Automated Script:**  
Run this one-liner on your Proxmox host to configure GRUB and kernel modules (requires reboot).
```
ssh root@proxmox-ip 'bash -s' < infrastructure/scripts/enable-host-igpu.sh
```

**Manual Verification:**  
Ensure `/etc/default/grub` contains `intel_iommu=on` and `/etc/modules` loads `kvmgt`, `vfio-iommu-type1`, and `vfio-mdev`.

---

## 🔄 CI/CD & Backups

- **Configuration**: All changes to `docker-compose.yml` files are versioned here.
- **Database Backups**: AppData (databases) should be backed up separately (e.g., via `scripts/backup-appdata.sh` cron job).
- **Secrets**: Never committed to Git. Managed via `.gitignore` and manual restoration from a password manager.

```
# Push changes to Git
./scripts/git-push.sh
```
