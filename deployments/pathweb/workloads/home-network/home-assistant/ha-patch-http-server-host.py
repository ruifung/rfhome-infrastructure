#!/usr/bin/env python3
"""Pre-patch UI-managed Home Assistant http config to bind to this pod's IP.

HA moved http server options out of configuration.yaml and into the
UI-managed store at /config/.storage/http. Override the stored server_host
(and nothing else) with the pod IP on every startup.
"""
import json
import os
import sys

HTTP_STORE = "/config/.storage/http"


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: http-patch.py <pod-ip>", file=sys.stderr)
        sys.exit(1)
    pod_ip = sys.argv[1]
    if not pod_ip:
        print("refusing to patch with empty pod ip", file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(HTTP_STORE):
        print(f"skip: {HTTP_STORE} not found (fresh install)", file=sys.stderr)
        return

    with open(HTTP_STORE, encoding="utf-8") as f:
        data = json.load(f)
    stable = data.setdefault("data", {}).setdefault("stable", {})
    stable["server_host"] = [pod_ip]
    with open(HTTP_STORE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4)
    print(f"patched {HTTP_STORE}: server_host={pod_ip}")


if __name__ == "__main__":
    main()
