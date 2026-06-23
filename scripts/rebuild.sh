#!/usr/bin/env bash
# On-demand rebuild to pull the NEWEST Geofabrik USA map.
# Destructively clears the cached PBF + tiles, then rebuilds from scratch.
#
# Usage: scripts/rebuild.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "!! This will DELETE cached tiles + PBF in ./custom_files and rebuild"
echo "!! from the newest Geofabrik USA map (several hours, ~100+ GB disk)."
read -r -p "Continue? [y/N] " reply
case "$reply" in
  [yY][eE][sS]|[yY]) ;;
  *) echo "Aborted."; exit 1 ;;
esac

echo ">> Stopping container..."
docker compose down

echo ">> Removing cached map + tiles..."
# Remove generated artifacts but keep the directory + any user config.
rm -rf \
  custom_files/*.pbf \
  custom_files/*.osm.pbf \
  custom_files/valhalla_tiles \
  custom_files/valhalla_tiles.tar \
  custom_files/*.tar \
  custom_files/timezones.sqlite \
  custom_files/admins.sqlite \
  custom_files/elevation_data

echo ">> Rebuilding from newest map..."
exec "$(dirname "$0")/build.sh"
