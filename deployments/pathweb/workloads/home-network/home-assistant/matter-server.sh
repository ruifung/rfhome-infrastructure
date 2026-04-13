#!/usr/bin/env bash

# Logging helper
log() {
    echo "[MatterWrapper] $1"
}

log "Matter server wrapper: Started."

# Wait for leader locker to be ready by waiting for a shared lock on the signal start file.
# The locker sidecar creates this file and takes an exclusive lock on it while it's settling.
# We wait for the file to exist first to ensure the locker had time to take the exclusive lock.
log "Waiting for leader lock signal..."
while [ ! -f /signal/lock-obtained ]; do sleep 0.1; done
flock -s /signal/lock-obtained true

log "Leader lock signal detected. Starting Matter server..."

# Launch the Matter server in the background
# Ensure unbuffered output for container logs
export PYTHONUNBUFFERED=1
matter-server "$@" &
MATTER_PID=$!

# Signal handler function to propagate K8s graceful shutdown signals
shutdown_handler() {
    SIGNAL=$1
    # Stop the monitor to avoid killing the process during graceful shutdown
    kill "$MONITOR_PID" 2>/dev/null
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
    # Block until the kill lock is released (leader lost lock or exited)
    # Since the leader holds it exclusively, this shared lock attempt will block.
    flock -s /signal/lock-lost true

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
