import { ConfigPatch } from '../types/ConfigPatch';

export const watchdogPatch: ConfigPatch = {
    apiVersion: 'v1alpha1',
    kind: 'WatchdogTimerConfig',
    device: '/dev/watchdog0',
    timeout: '5m'
}
