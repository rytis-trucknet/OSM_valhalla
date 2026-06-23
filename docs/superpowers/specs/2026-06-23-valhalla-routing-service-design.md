# Valhalla USA Routing Service — Design

**Date:** 2026-06-23
**Status:** Approved

## Purpose

Run a self-hosted [Valhalla](https://github.com/valhalla/valhalla) routing engine
in Docker, covering the full continental USA (lower 48), so other local scripts
can query routing, matrix, and isochrone endpoints over HTTP — including
**truck** routing. Patterned after the `gas_prices` project: a Dockerized service
defined via `docker-compose.yml`, queried by external scripts.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Coverage | Full USA, lower 48 | Geofabrik `us-latest.osm.pbf` (~10 GB). |
| Build approach | `gis-ops/docker-valhalla` image | Mature, includes truck costing for free; no source build to maintain. |
| Truck routing | Built-in costing model | `"costing": "truck"` per-request; USA tiles already encode weight/height/length/hazmat tags. |
| Access | Localhost port `8002` | Scripts on the same host hit `http://localhost:8002`. |
| Download / rebuild | **Fully manual, explicit** | Nothing auto-downloads or auto-rebuilds. The user is always the trigger. |
| Elevation | Off initially | Faster first build; toggleable later for grade-aware truck costing. |

## Architecture

A single Docker Compose service using
`ghcr.io/gis-ops/docker-valhalla/valhalla:latest`.

- The image's data directory (`/custom_files`) is bind-mounted to `./custom_files`
  so the PBF + built tiles persist across container restarts and rebuilds.
- HTTP API published on host port **8002**.
- `restart: unless-stopped`.

### Three distinct, intentional actions

1. **Serve (default — `docker compose up -d`)**
   - Env: `force_rebuild=False`, `use_tiles_ignore_pbf=True`, `serve_tiles=True`.
   - Serves whatever tiles already exist in `custom_files/`.
   - Never downloads, never rebuilds, even if a newer PBF exists upstream.
   - Instant startup. This is the steady state.

2. **Build (once — `scripts/build.sh`)**
   - Run a one-time initial build: download `us-latest.osm.pbf` and build tiles.
   - Implemented by invoking the container with build env flags set
     (`force_rebuild=True`), then the service returns to normal serve mode.

3. **Rebuild (on demand — `scripts/rebuild.sh`)**
   - Run only when the user wants the newest Geofabrik USA map.
   - Stops the container, removes cached artifacts from `custom_files/`
     (the `*.pbf`, `valhalla_tiles*`, `*.tar`, and generated config if needed),
     then re-runs the build to download the latest PBF and rebuild tiles.

> Builds take a few hours and need substantial disk (plan ~100+ GB free) and
> RAM. The service is unavailable during a build/rebuild. These costs are
> documented in the README.

## Data Flow

External scripts POST JSON to the Valhalla HTTP API:

- `POST /route` — turn-by-turn routing
- `POST /sources_to_targets` (matrix) — many-to-many time/distance
- `POST /isochrone` — reachability polygons
- `POST /optimized_route` — TSP-style ordering
- `GET  /status` — health / loaded-tile check

Truck queries pass `"costing": "truck"` plus optional
`costing_options.truck` (height, weight, axle_load, length, width, hazmat).

## Repository Layout

```
osm_valhalla/
├── docker-compose.yml      # the Valhalla service (serve-by-default)
├── .env.example            # PBF URL, host port, build flags
├── .gitignore              # excludes custom_files/ (large data)
├── README.md               # start/build/rebuild instructions + query examples
├── scripts/
│   ├── build.sh            # one-time initial download + tile build
│   └── rebuild.sh          # on-demand: clear cache, fetch newest map, rebuild
├── examples/
│   └── route_truck.py      # reference truck-route client for other scripts
└── docs/superpowers/specs/ # this design
```

## Configuration (env, overridable via `.env`)

| Var | Default | Meaning |
|-----|---------|---------|
| `VALHALLA_PORT` | `8002` | Host port for the HTTP API. |
| `PBF_URL` | `https://download.geofabrik.de/north-america/us-latest.osm.pbf` | Source map. |
| `BUILD_ELEVATION` | `False` | Grade-aware costing; off for faster first build. |
| `BUILD_ADMINS` | `True` | Needed for correct border/country logic. |
| `BUILD_TIME_ZONES` | `True` | Time-zone-aware time fields. |

Compose maps these onto the gis-ops image's expected env vars
(`tile_urls`, `build_elevation`, `build_admins`, `build_time_zones`,
`force_rebuild`, `serve_tiles`, `use_tiles_ignore_pbf`).

## Error Handling / Operational Notes

- `.gitignore` excludes `custom_files/` so the ~10 GB of data is never committed.
- Default serve mode is network-free and rebuild-free, so a crash/restart can
  never silently re-download or wipe tiles.
- `scripts/rebuild.sh` prompts/echoes a clear warning before deleting cached
  tiles, since rebuild is destructive and long-running.
- README documents disk/RAM/time expectations and how to verify tiles loaded
  via `GET /status`.

## Testing / Verification

- After `build.sh`, verify `GET http://localhost:8002/status` reports loaded
  tiles.
- Smoke test a real truck route (two US coordinates) via `examples/route_truck.py`
  and confirm a valid trip is returned.
- Confirm a plain `docker compose up` after a build performs no download/rebuild
  (check logs show serve mode only).

## Out of Scope (YAGNI)

- Building Valhalla from source.
- Canada/Mexico or cross-border routing.
- Authentication / public exposure (localhost only).
- Live traffic feeds.
