# 🚀 Media Server Infrastructure (IaC)

![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Plex](https://img.shields.io/badge/Plex-E5A00D?style=for-the-badge&logo=plex&logoColor=white)

**Automated, version-controlled infrastructure for a self-hosted media server.**  
This repository contains the `docker-compose` stacks, configuration templates, and Proxmox automation scripts to deploy a complete media stack.

---

## 📂 Repository Structure

| Path | Description |
| :--- | :--- |
| **`media-server-stack/`** | Core Infrastructure (`Dockge`, `Traefik`, etc.) |
| **`media-download-stack/`** | VPN & Downloads (`Gluetun`, `qBittorrent`) |
| **`media-content-stack/`** | Content Management (`Sonarr`, `Radarr`, `Prowlarr`) |
| **`infrastructure/`** | Proxmox Automation Scripts (`LXC creation`, `Host setup`) |
| **`config-templates/`** | Secure templates for `.env` and secrets |

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
```
# Example for Gluetun VPN
cp config-templates/env/gluetun.env.example media-download-stack/env/gluetun.env

# Example for API Keys
cp config-templates/secrets/cloudflare_api_token.example media-server-stack/secrets/cloudflare_api_token
```

### 3. Launch Stacks
Deploy all Docker services using the helper script or manually.
```
# Deploy core infrastructure first
docker compose -f media-server-stack/docker-compose.yml up -d

# Deploy other stacks
docker compose -f media-download-stack/docker-compose.yml up -d
docker compose -f media-content-stack/docker-compose.yml up -d
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

### 2. Deploy Plex LXC
Automatically creates a privileged LXC container for Plex with:
- **Static IP**: `10.0.0.215` (configurable)
- **Storage**: `local-lvm` (10GB)
- **Mounts**: Media folder `/mnt/arrdata`
- **Hardware**: iGPU Passthrough enabled

**Deploy Command:**
```
ssh root@proxmox-ip 'bash -s' < infrastructure/scripts/create-plex-lxc.sh
```

**Customization:**  
Edit variables at the top of `infrastructure/scripts/create-plex-lxc.sh` to adjust settings like IP, CPU cores, or RAM before running.

---

## 🔄 CI/CD & Backups

- **Configuration**: All changes to `docker-compose.yml` files are versioned here.
- **Database Backups**: AppData (databases) should be backed up separately (e.g., via `scripts/backup-appdata.sh` cron job).
- **Secrets**: Never committed to Git. Managed via `.gitignore` and manual restoration from a password manager.

```
# Push changes to Git
./scripts/git-push.sh
```
