# Homepage Configuration

Homepage is a modern, customizable dashboard for your media stack with real-time metrics and service monitoring.

## Features

- **Real-time Service Metrics**: Live stats from Sonarr, Radarr, Prowlarr, Overseerr, qBittorrent, SABnzbd, etc.
- **System Monitoring**: CPU, RAM, disk usage, and uptime
- **Docker Integration**: Container status and resource usage
- **Fully Code-Based**: All configuration via YAML files (no GUI config needed)
- **Dark Theme**: Modern, clean interface

## Deployment Steps

### 1. Create Config Directory
```bash
mkdir -p /opt/data/media/appdata/homepage
```

### 2. Copy Configuration Files
```bash
cp config-templates/homepage/*.yaml /opt/data/media/appdata/homepage/
```

### 3. Set Up Environment Variables
```bash
cp config-templates/homepage/.env.example /opt/data/media/appdata/homepage/.env
```

### 4. Edit Environment Variables
Edit `/opt/data/media/appdata/homepage/.env` and add:
- Your server IP address
- API keys from each service (Settings -> General)
- qBittorrent credentials

### 5. Start Homepage
```bash
docker compose -f media-server-stack/docker-compose.yml up -d homepage
```

### 6. Access Dashboard
Open http://your-server-ip:3000

## Getting API Keys

### For Sonarr/Radarr/Lidarr/Prowlarr/Bazarr:
1. Open the service web UI
2. Go to Settings -> General
3. Copy the API Key

### For Overseerr:
1. Open Overseerr web UI
2. Go to Settings -> General
3. Copy the API Key

### For SABnzbd:
1. Open SABnzbd web UI
2. Go to Config -> General
3. Copy the API Key

### For qBittorrent:
Use your qBittorrent web UI credentials (default: admin/adminadmin)

## Customization

All configuration is in YAML files:

- `services.yaml` - Your service definitions and widgets
- `widgets.yaml` - System resource widgets
- `settings.yaml` - Theme, layout, and general settings
- `bookmarks.yaml` - Quick links to useful sites
- `docker.yaml` - Docker integration settings

Edit these files and restart Homepage to apply changes:
```bash
docker restart homepage
```

## Service Widget Examples

Homepage will show live metrics for each service:
- **Sonarr/Radarr/Lidarr**: Wanted, missing, queued items
- **Prowlarr**: Number of indexers, health status
- **Overseerr**: Pending requests, available/processing
- **qBittorrent**: Active torrents, download/upload speed
- **SABnzbd**: Queue size, download speed
- **Gluetun**: VPN status and connection info

## Troubleshooting

### Widgets not showing data:
- Check API keys are correct in `.env` file
- Verify services are accessible from Homepage container
- Check Homepage logs: `docker logs homepage`

### Icons not loading:
Icons are automatically fetched from the Homepage CDN. If custom icons are needed, place them in `/opt/data/media/appdata/homepage/icons/`

## Documentation

Full documentation: https://gethomepage.dev
