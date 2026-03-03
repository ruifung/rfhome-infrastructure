import { ConfigPatch, ConfigPatchProvider, v1alpha1Config } from '../types/ConfigPatch';

export const watchdogPatch: ConfigPatchProvider = () => [
    v1alpha1Config('WatchdogTimerConfig', {device: '/dev/watchdog0', timeout: '5m'})
]
