#!/usr/bin/env python3
"""Generate/update the UI-managed Home Assistant http config from a desired-state file.

HA stores http server options in the UI-managed store at /config/.storage/http,
not configuration.yaml. On startup this script reads a desired-state http block
(an `http:` YAML mapping, mounted read-only from a ConfigMap) and writes it into
HA's store, binding the server to this pod's IP.

Behavior:
- If /config/.storage/http is missing or blank/corrupt, a fresh store is
  generated from the desired-state file.
- If it exists and is valid, it is updated to match the desired state, with
  server_host always forced to the pod IP.
- Both the `stable` and (when present) `pending` slots are patched: HA prefers
  `pending` on a normal boot, so a stale pending config must not win.

Validation uses Home Assistant's own http storage schema
(homeassistant.components.http.config), so it tracks the installed HA version.
"""
import json
import os
import sys
import tempfile
from datetime import datetime, timezone

import yaml

HTTP_STORE = "/config/.storage/http"


def _desired_config(src_file: str, pod_ip: str) -> dict | None:
    """Parse the desired http block and normalize it against HA's schema.

    Returns a validated store `stable`/`pending` slot dict (including HA's
    created_at/error metadata) or None if the file is unusable.
    """
    try:
        with open(src_file, encoding="utf-8") as f:
            doc = yaml.safe_load(f)
    except (yaml.YAMLError, UnicodeDecodeError, OSError) as err:
        print(f"warn: cannot read desired http config {src_file} ({err}); skipping patch", file=sys.stderr)
        return None

    http_conf = doc.get("http") if isinstance(doc, dict) else None
    if not isinstance(http_conf, dict) or not http_conf:
        print(f"warn: no http block in {src_file}; skipping patch", file=sys.stderr)
        return None

    try:
        from homeassistant.components.http.config import HTTP_STORAGE_SCHEMA
    except Exception as err:  # pragma: no cover - import env dependent
        print(f"warn: cannot import HA http config module ({err}); skipping patch", file=sys.stderr)
        return None

    try:
        slot = dict(HTTP_STORAGE_SCHEMA(http_conf))
    except Exception as err:
        print(f"warn: desired http config invalid ({err}); skipping patch", file=sys.stderr)
        return None

    slot["server_host"] = [pod_ip]
    slot["created_at"] = datetime.now(timezone.utc).isoformat()
    slot["error"] = None
    slot["error_message"] = None
    return slot


def _load_existing() -> dict | None:
    """Return the parsed store, or None if missing/blank/corrupt."""
    if not os.path.exists(HTTP_STORE):
        return None
    try:
        with open(HTTP_STORE, encoding="utf-8") as f:
            data = json.load(f)
    except (json.JSONDecodeError, UnicodeDecodeError, OSError):
        return None
    return data if isinstance(data, dict) else None


def _write_atomic(data: dict) -> None:
    """Write the store atomically (tmp file + rename)."""
    os.makedirs(os.path.dirname(HTTP_STORE), exist_ok=True)
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


def main() -> None:
    if len(sys.argv) != 3:
        print("usage: sync-http-settings.py <pod-ip> <http-config-file>", file=sys.stderr)
        sys.exit(1)
    pod_ip = sys.argv[1]
    src_file = sys.argv[2]
    if not pod_ip:
        print("refusing to patch with empty pod ip", file=sys.stderr)
        sys.exit(1)
    if not os.path.exists(src_file):
        print(f"warn: desired http config {src_file} not found; skipping patch", file=sys.stderr)
        return

    desired = _desired_config(src_file, pod_ip)
    if desired is None:
        return

    existing = _load_existing()

    if existing is not None and isinstance(existing.get("data"), dict):
        inner = existing["data"]
        pending = inner.get("pending")
        if not isinstance(pending, dict):
            pending = None
        yaml_done = inner.get("yaml_migration_done")
        if not isinstance(yaml_done, bool):
            yaml_done = True
        # HA prefers pending on a normal boot; keep any existing pending slot
        # in sync with the desired state so a stale pending config never wins.
        if pending is not None:
            pending.update(desired)
    else:
        pending = None
        yaml_done = True

    try:
        from homeassistant.components.http.config import (
            STORAGE_KEY,
            STORAGE_MINOR_VERSION,
            STORAGE_VERSION,
        )
    except Exception as err:  # pragma: no cover - import env dependent
        print(f"warn: cannot import HA http config module ({err}); skipping patch", file=sys.stderr)
        return

    data = {
        "version": STORAGE_VERSION,
        "minor_version": STORAGE_MINOR_VERSION,
        "key": STORAGE_KEY,
        "data": {
            "stable": desired,
            "pending": pending,
            "yaml_migration_done": yaml_done,
        },
    }

    _write_atomic(data)
    print(f"patched {HTTP_STORE}: server_host={pod_ip}")


if __name__ == "__main__":
    main()
