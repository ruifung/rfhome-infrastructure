#!/usr/bin/env python3
import asyncio
import json
import os
import shutil
import sys
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
    """Run `tailscale status --json --peers=false` and return parsed JSON.
    """
    rc, stdout, stderr = await run_tailscale_cmd(["status", "--json", "--peers=false"])
    if rc != 0:
        raise RuntimeError(f"{stderr.strip() or 'tailscale status failed'}")
    return json.loads(stdout)


async def run_tailscale_cmd(args, timeout: int | None = None):
    """Run `tailscale` with the given args and return (returncode, stdout, stderr).

    `args` should be a list of arguments (e.g. ['status', '--json']).
    """
    proc = await asyncio.create_subprocess_exec(
        "tailscale", *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    return proc.returncode, stdout.decode(), stderr.decode()


async def set_tailscale_exit_node(enable: bool):
    """Enable or disable advertising as a Tailscale exit node.

    Runs `tailscale set --advertise-exit-node` when `enable` is True, or
    `tailscale set --advertise-exit-node=false` when `enable` is False.
    """
    cmd_args = ["set", "--advertise-exit-node"] if enable else ["set", "--advertise-exit-node=false"]

    rc, stdout, stderr = await run_tailscale_cmd(cmd_args)
    if rc == 0:
        print(f"🔁 tailscale exit-node {'enabled' if enable else 'disabled'}")
    else:
        err = stderr.strip() or stdout.strip()
        print(f"❌ tailscale set advertise-exit-node failed: {err}")


async def manage_bird(expected_routes, socket_path, control_exit_node: bool = True):
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
                if control_exit_node:
                    await set_tailscale_exit_node(True)
            elif (not online or not has_routes) and bird.last_state != "disable":
                print("🛑 Node is offline or not the primary router for all expected routes. Disabling BIRD protocols...")
                await bird.send_state("disable")
                if control_exit_node:
                    await set_tailscale_exit_node(False)

        except Exception:
            if last_health != "unhealthy":
                print("❌ Healthcheck: tailscale command failed (tailscaled unhealthy). Protocols disabled.")
                last_health = "unhealthy"
            if bird.last_state != "disable":
                await bird.send_state("disable")
                if control_exit_node:
                    await set_tailscale_exit_node(False)

        await asyncio.sleep(CHECK_INTERVAL)

def main():
    parser = argparse.ArgumentParser(
        description="Manage BIRD protocols based on Tailscale primary routes and online status."
    )
    parser.add_argument("socket_path", help="Path to the BIRD control socket (e.g. /run/bird/bird.ctl)")
    parser.add_argument("routes", nargs="+", help="Expected routes for which this node must be the primary router")
    parser.add_argument(
        "--no-exit-node",
        action="store_true",
        help="Do not toggle Tailscale exit-node advertising when enabling/disabling protocols",
    )
    args = parser.parse_args()

    # Check once at startup whether the `tailscale` binary is present; bail if missing.
    if shutil.which("tailscale") is None:
        print("❌ tailscale binary not found in PATH; this script requires tailscale. Exiting.")
        sys.exit(1)
    else:
        print("✅ tailscale binary found in PATH. Will control exit-node when configured.")

    if not os.path.exists(args.socket_path):
        print(f"⚠️ Warning: socket {args.socket_path} does not exist yet. Will retry on reconnect.")

    print(f"⏱️ CHECK_INTERVAL={CHECK_INTERVAL}s, 🔄 RECONNECT_INTERVAL={RECONNECT_INTERVAL}s")
    asyncio.run(manage_bird(args.routes, args.socket_path, control_exit_node=not args.no_exit_node))

if __name__ == "__main__":
    main()
