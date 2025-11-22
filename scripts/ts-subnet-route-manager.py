#!/usr/bin/env python3
import asyncio
import json
import os
import argparse
import re

# Optional env overrides
CHECK_INTERVAL = int(os.getenv("CHECK_INTERVAL", "5"))        # seconds
RECONNECT_INTERVAL = int(os.getenv("RECONNECT_INTERVAL", "2"))  # seconds

# Protocols managed by this script (list for easier modification)
BIRD_PROTOCOLS = ["tailscale", "tailscale6"]

class BirdSocketClient:
    def __init__(self, socket_path):
        self.socket_path = socket_path
        self.reader = None
        self.writer = None
        self.last_state = None  # "enable" or "disable"
        self.lock = asyncio.Lock()


    async def connect(self):
        """Attempt a single connection to the BIRD control socket."""
        try:
            reader, writer = await asyncio.open_unix_connection(self.socket_path)
            # Expect a greeting line immediately
            line = await reader.readline()
            if not line:
                print("❌ No greeting received from BIRD, closing socket.")
                try:
                    writer.close()
                except Exception:
                    pass
                self.reader, self.writer = None, None
                return

            decoded = line.decode(errors="ignore").strip()
            if re.search(r"^0001\s+BIRD\s+[\d.]+\s+ready", decoded):
                print(f"✅ Greeting received: {decoded}")
                self.reader, self.writer = reader, writer
                # Start monitoring the reader side
                asyncio.create_task(self.monitor_reader())
                # Re‑issue last state if known
                if self.last_state:
                    asyncio.create_task(self.send_state(self.last_state, force=True))
            else:
                print(f"⚠️ Unexpected greeting: {decoded}, closing socket.")
                try:
                    writer.close()
                except Exception:
                    pass
                self.reader, self.writer = None, None

        except Exception as e:
            print(f"⚠️ Connect failed: {e}")
            self.reader, self.writer = None, None


    async def monitor_reader(self):
        """Continuously read from the socket to detect daemon exit (EOF)."""
        try:
            while True:
                line = await self.reader.readline()
                if not line:
                    print("❌ BIRD socket closed by daemon, reconnecting...")
                    async with self.lock:
                        try:
                            self.writer.close()
                        except Exception:
                            pass
                        self.reader, self.writer = None, None
                    return
        except Exception as e:
            print(f"⚠️ Reader error: {e}")
            async with self.lock:
                self.reader, self.writer = None, None

    async def ensure_connected(self):
        """Background task: keep the socket connected."""
        while True:
            async with self.lock:
                if self.writer is None or self.writer.is_closing():
                    await self.connect()
            await asyncio.sleep(RECONNECT_INTERVAL)

    async def send_state(self, state, force=False):
        async with self.lock:
            if not self.writer or self.writer.is_closing():
                await self.connect()
            if self.writer:
                try:
                    for proto in BIRD_PROTOCOLS:
                        cmd = f"{state} {proto}\n"
                        self.writer.write(cmd.encode())
                    await self.writer.drain()
                    print(f"📡 Sent '{state}' for {', '.join(BIRD_PROTOCOLS)}")
                    self.last_state = state
                except Exception as e:
                    print(f"❌ Error writing to BIRD socket: {e}")
                    try:
                        self.writer.close()
                    except Exception:
                        pass
                    self.reader, self.writer = None, None

async def get_tailscale_status():
    """Run tailscale status --json --peers=false and return parsed JSON."""
    proc = await asyncio.create_subprocess_exec(
        "tailscale", "status", "--json", "--peers=false",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    if proc.returncode != 0:
        raise RuntimeError(f"{stderr.decode().strip() or 'tailscale status failed'}")
    return json.loads(stdout.decode())

async def manage_bird(expected_routes, socket_path):
    expected_set = set(expected_routes)
    bird = BirdSocketClient(socket_path)
    asyncio.create_task(bird.ensure_connected())

    last_health = None  # "healthy" or "unhealthy"

    while True:
        try:
            status = await get_tailscale_status()
            if last_health != "healthy":
                print("✅ Healthcheck: tailscale command succeeded (tailscaled healthy).")
                last_health = "healthy"

            self_info = status.get("Self", {})
            self_routes = set(self_info.get("PrimaryRoutes", []))
            online = self_info.get("Online", False)
            has_routes = expected_set.issubset(self_routes)

            if online and has_routes and bird.last_state != "enable":
                print("🚀 Node is online and the primary router for all expected routes. Enabling BIRD protocols...")
                await bird.send_state("enable")
            elif (not online or not has_routes) and bird.last_state != "disable":
                print("🛑 Node is offline or not the primary router for all expected routes. Disabling BIRD protocols...")
                await bird.send_state("disable")

        except Exception:
            if last_health != "unhealthy":
                print("❌ Healthcheck: tailscale command failed (tailscaled unhealthy). Protocols disabled.")
                last_health = "unhealthy"
            if bird.last_state != "disable":
                await bird.send_state("disable")

        await asyncio.sleep(CHECK_INTERVAL)

def main():
    parser = argparse.ArgumentParser(
        description="Manage BIRD protocols based on Tailscale primary routes and online status."
    )
    parser.add_argument("socket_path", help="Path to the BIRD control socket (e.g. /run/bird/bird.ctl)")
    parser.add_argument("routes", nargs="+", help="Expected routes for which this node must be the primary router")
    args = parser.parse_args()

    if not os.path.exists(args.socket_path):
        print(f"⚠️ Warning: socket {args.socket_path} does not exist yet. Will retry on reconnect.")

    print(f"⏱️ CHECK_INTERVAL={CHECK_INTERVAL}s, 🔄 RECONNECT_INTERVAL={RECONNECT_INTERVAL}s")
    asyncio.run(manage_bird(args.routes, args.socket_path))

if __name__ == "__main__":
    main()
