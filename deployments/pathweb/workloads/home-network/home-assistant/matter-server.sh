#!/usr/bin/env bash

# Logging helper
log() {
    echo "[MatterWrapper] $1"
}

log "Matter server wrapper: Started."

# Wait for leader locker to signal start
# Log every 30 seconds to provide a status heartbeat without flooding logs
WAIT_COUNT=0
while [ ! -f /signal/is_leader ]; do
    if [ $((WAIT_COUNT % 15)) -eq 0 ]; then
        log "Still waiting for leader lock signal at /signal/is_leader..."
    fi
    WAIT_COUNT=$((WAIT_COUNT + 1))
    sleep 2
done

log "Leader lock signal detected. Starting Matter server..."

# Launch the Matter server in the background
# Ensure unbuffered output for container logs
export PYTHONUNBUFFERED=1
matter-server "$@" &
MATTER_PID=$!

# Signal handler function to propagate K8s graceful shutdown signals
shutdown_handler() {
    SIGNAL=$1
    log "Caught $SIGNAL. Propagating to Matter server (PID $MATTER_PID) for graceful shutdown..."
    kill -TERM "$MATTER_PID" 2>/dev/null
    wait "$MATTER_PID"
    exit $?
}

# Trap SIGTERM and SIGINT (used by Kubernetes for graceful pod shutdown)
trap "shutdown_handler SIGTERM" SIGTERM
trap "shutdown_handler SIGINT" SIGINT

# Monitor loop in background for emergency lock loss
(
    while [ -f /signal/is_leader ]; do
        sleep 2
    done

    # Output to stderr for immediate visibility
    echo "[MatterMonitor] CRITICAL: Leader lock lost! Executing emergency hard-kill of Matter server (PID $MATTER_PID)." >&2
    kill -9 "$MATTER_PID"
    exit 1
) &
MONITOR_PID=$!

# Wait for the Matter server process to exit naturally (or via the signal handler above)
wait "$MATTER_PID"
EXIT_STATUS=$?

# Cleanup the monitor loop and exit with the Matter server's exit code
kill "$MONITOR_PID" 2>/dev/null
exit "$EXIT_STATUS"
