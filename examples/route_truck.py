#!/usr/bin/env python3
"""Reference client: request a truck route from the local Valhalla service.

Run the service first (docker compose up), then:
    python examples/route_truck.py
Other scripts can import route_truck() or copy this pattern.
"""
import json
import os
import sys

import requests

BASE_URL = os.environ.get("VALHALLA_URL", "http://localhost:8002")


def route_truck(start, end, base_url=BASE_URL):
    """Return Valhalla's JSON route for a truck between two (lat, lon) points.

    start, end: (lat, lon) tuples.
    """
    payload = {
        "locations": [
            {"lat": start[0], "lon": start[1]},
            {"lat": end[0], "lon": end[1]},
        ],
        "costing": "truck",
        "costing_options": {
            "truck": {
                "height": 4.11,
                "width": 2.6,
                "length": 21.64,
                "weight": 36.3,
                "axle_load": 9.07,
                "hazmat": False,
            }
        },
        "units": "miles",
    }
    resp = requests.post(f"{base_url}/route", json=payload, timeout=30)
    resp.raise_for_status()
    return resp.json()


def main():
    # Chicago, IL -> Indianapolis, IN
    start = (41.8781, -87.6298)
    end = (39.7684, -86.1581)
    result = route_truck(start, end)
    if "trip" not in result:
        print(f"Valhalla returned no trip: {result}", file=sys.stderr)
        sys.exit(1)
    summary = result["trip"]["summary"]
    print(f"Distance: {summary['length']:.1f} mi, "
          f"time: {summary['time'] / 3600:.2f} h")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    try:
        main()
    except requests.RequestException as exc:
        print(f"Request failed: {exc}", file=sys.stderr)
        sys.exit(1)
