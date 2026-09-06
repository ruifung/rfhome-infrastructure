#!/usr/bin/env python3
"""Pre-patch UI-managed Home Assistant http config to bind to this pod's IP.

HA moved http server options out of configuration.yaml and into the
UI-managed store at /config/.storage/http. Override the stored server_host
(and nothing else) with the pod IP on every startup.
"""
import json
import os
import sys
import tempfile

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

    try:
        with open(HTTP_STORE, encoding="utf-8") as f:
            data = json.load(f)
    except (json.JSONDecodeError, UnicodeDecodeError, OSError) as err:
        # Empty/corrupt store (e.g. unclean shutdown or a killed mid-write
        # peer). HA's own Store.load already tolerates this by renaming the
        # corrupt file and starting fresh, so we must not crash HA startup
        # here. Skip and let HA regenerate.
        print(
            f"warn: {HTTP_STORE} unreadable ({err}); "
            "skipping patch, HA will regenerate the store",
            file=sys.stderr,
        )
        return

    stable = data.setdefault("data", {}).setdefault("stable", {})
    stable["server_host"] = [pod_ip]
    # Write atomically (tmp file + rename) so a killed pod never leaves the
    # store truncated/empty. The shared PVC may be accessed by an old pod
    # still draining during a rolling update.
    fd, tmp_path = tempfile.mkstemp(
        dir=os.path.dirname(HTTP_STORE), prefix=".http-store-", suffix=".tmp"
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=4)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp_path, HTTP_STORE)
    except OSError:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise
    print(f"patched {HTTP_STORE}: server_host={pod_ip}")


if __name__ == "__main__":
    main()
