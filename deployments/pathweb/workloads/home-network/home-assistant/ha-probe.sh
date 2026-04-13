#!/bin/sh
# ha-probe.sh - Home Assistant Lock-Aware Health Probe

# This script is used for both Liveness and Readiness probes.
# It ensures the pod is reported as healthy/ready during the leader election
# and settle phases, allowing for warm spares and seamless rolling updates.
# Actual application health is checked only when the pod is the active leader.

# 1. Identify leadership status.
# The leader-locker sidecar holds an exclusive lock on /signal/lock-lost
# if it has successfully acquired the leadership lock on CephFS.
if [ -f /signal/lock-lost ] && ! flock -n -s /signal/lock-lost true; then

    # 2. Check if the 10-second settle period has passed.
    # The leader-locker sidecar holds an exclusive lock on /signal/lock-obtained
    # during the 10s wait, and releases it once the pod is ready to serve.
    if [ -f /signal/lock-obtained ] && flock -n -s /signal/lock-obtained true; then
        # The pod is the active leader and has settled.
        # Perform the actual application health check via curl.
        # We use POD_IP (populated via Downward API) to avoid binding issues.
        TARGET_IP=${POD_IP:-localhost}
        exec curl -sSf --max-time 2 "http://$TARGET_IP:8123/"
    fi
fi

# 3. Default to success for all other states:
# - Pod is a warm spare waiting for leadership.
# - Pod is in the 10-second settle period.
# - Signal files are not yet created.
exit 0
