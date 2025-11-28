#!/bin/sh
last_state="starting"
while true; do
  state=$(docker inspect --format "{{ .State.Health.Status }}" gluetun 2>/dev/null || echo "missing")
  if [ "$last_state" = "unhealthy" ] && [ "$state" = "healthy" ]; then
    echo "[Watchdog] Gluetun recovered → restarting qbittorrent"
    docker restart qbittorrent
  fi
  last_state=$state
  sleep 20
done
