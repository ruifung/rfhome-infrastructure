#!/bin/sh
check_lock() {
  flock -n /config/hass.lock -c "true"
  RET=$?
  if [ $RET -eq 0 ]; then
    echo "Lock lost! $1"
    exit 1
  elif [ $RET -ne 1 ]; then
    echo "Lock check failed! $1 (error: $RET)"
    exit 1
  fi
}
trap "rm -f /signal/is_leader; exit" EXIT SIGTERM
rm -f /signal/is_leader
echo "Attempting to acquire lock on CephFS..."
exec 200>/config/hass.lock
flock -x 200 || exit 1
echo "Lock acquired! Waiting 10s before signaling leader status..."
sleep 10
check_lock "Exclusive lock no longer held after wait."
echo "Lock confirmed! Signaling leader status."
touch /signal/is_leader
while true; do
  check_lock "Exclusive lock lost."
  sleep 5
done
