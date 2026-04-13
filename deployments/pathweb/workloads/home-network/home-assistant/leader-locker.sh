#!/bin/sh
trap "rm -f /signal/lock-obtained /signal/lock-lost; exit" EXIT SIGTERM

# 1. Take kill lock immediately. This will be held as long as this container is leader.
touch /signal/lock-lost
exec 202>/signal/lock-lost
flock -x 202 || exit 1

# 2. Take start lock. This blocks other containers until we finish the 10s wait.
touch /signal/lock-obtained
exec 201>/signal/lock-obtained
flock -x 201 || exit 1

echo "Attempting to acquire lock on CephFS..."
# File descriptor 200 will hold the exclusive lock on the shared volume.
exec 200>/config/hass.lock
flock -x 200 || exit 1

echo "Lock acquired! Waiting 10s before signaling leader status..."
sleep 10

# Post-wait check: Ensure we still have the lock on FD 200.
# flock -n on an existing FD will fail if the lock was revoked and taken by another client.
if ! flock -n 200; then
  echo "CRITICAL: Exclusive lock lost during wait period!" >&2
  exit 1
fi

echo "Lock confirmed! Signaling leader status."
# Release start lock to allow other containers to proceed
exec 201>&-

# 3. Monitoring: Block until the lock is lost or revoked.
# Since we hold the lock on FD 200, another flock attempt on the SAME file will block
# until our primary lock is released or revoked by the filesystem.
# This provides zero-latency detection without needing a background subshell.
echo "Monitoring lock (blocking wait)..."
flock -x /config/hass.lock true

echo "CRITICAL: Exclusive lock lost or revoked! Signaling leader loss." >&2
exit 1
