#!/usr/bin/env python3
import asyncio
import json
import argparse

async def get_tailscale_status():
    """Run tailscale status --json and return parsed JSON."""
    proc = await asyncio.create_subprocess_exec(
        "tailscale", "status", "--json",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    if proc.returncode != 0:
        raise RuntimeError(f"tailscale failed: {stderr.decode().strip()}")
    return json.loads(stdout.decode())

async def find_peers_with_routes(expected_routes):
    status = await get_tailscale_status()
    expected_set = set(expected_routes)

    # Check Self
    self_info = status.get("Self", {})
    self_routes = set(self_info.get("PrimaryRoutes", []))
    if expected_set.issubset(self_routes):
        print(f"Self ({self_info.get('DNSName')})")

    # Check Peers
    peers = status.get("Peer", {})
    for peer_id, peer_info in peers.items():
        peer_routes = set(peer_info.get("PrimaryRoutes", []))
        if expected_set.issubset(peer_routes):
            print(f"{peer_id} ({peer_info.get('DNSName')})")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Check which Tailscale nodes are the primary router for the given subnet routes."
    )
    parser.add_argument(
        "routes",
        nargs="+",
        help="One or more subnet routes to check (e.g. 10.0.0.0/24)"
    )

    args = parser.parse_args()

    expected_routes = args.routes
    asyncio.run(find_peers_with_routes(expected_routes))
