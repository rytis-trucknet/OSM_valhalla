#!/usr/bin/env bash
# One-time / explicit build: download the USA PBF and build routing tiles,
# then return the service to normal serve mode.
#
# Usage: scripts/build.sh
# WARNING: downloads ~10 GB and builds for several hours; needs ~100+ GB free
# disk and substantial RAM. The service is unavailable during the build.
set -euo pipefail

cd "$(dirname "$0")/.."

echo ">> Stopping any running Valhalla container..."
docker compose down

echo ">> Building tiles (download + tile build). This takes hours..."
# Override serve-mode defaults so the image actually downloads + builds.
FORCE_REBUILD=True USE_TILES_IGNORE_PBF=False docker compose up -d

echo ">> Build started in the background. Follow progress with:"
echo "   docker compose logs -f valhalla"
echo ">> When logs show the tiles are loaded and the server is listening,"
echo "   the API is live on http://localhost:${VALHALLA_PORT:-8002}"
echo ">> Tiles are now cached in ./custom_files; future 'docker compose up'"
echo "   will serve them without rebuilding."
