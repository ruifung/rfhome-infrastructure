import { TypedConfigPatchProvider, v1alpha1Config } from '../types/ConfigPatch';

export const watchdogPatch: TypedConfigPatchProvider = () => [
    v1alpha1Config('WatchdogTimerConfig', {device: '/dev/watchdog0', timeout: '5m'})
]
