import { NodeDefinition } from './types/NodeDefinition'
import * as schematics from '../talos-schematics'

const rfhomeLabels = {
    location: 'rfhome',
    type: 'proxmox-x64',
    'topology.kubernetes.io/region': 'rfhome'
}

export const control1: NodeDefinition = {
    address: '10.229.97.31',
    hostname: 'pathweb-control-1',
    role: 'controlplane',
    schematic: schematics.nocloud.qemu.default,
    labels: {
        ...rfhomeLabels,
    }
}

export const control2: NodeDefinition = {
    address: '10.229.97.32',
    hostname: 'pathweb-control-2',
    role: 'controlplane',
    schematic: schematics.nocloud.qemu.default,
    labels: {
        ...rfhomeLabels,
    }
}

export const control3: NodeDefinition = {
    address: '10.229.97.33',
    hostname: 'pathweb-control-3',
    role: 'controlplane',
    schematic: schematics.nocloud.qemu.default,
    labels: {
        ...rfhomeLabels
    }
}

export const worker1: NodeDefinition = {
    address: '10.229.97.34',
    hostname: 'pathweb-worker-1',
    role: 'worker',
    schematic: schematics.nocloud.qemu.default,
    labels: {
        ...rfhomeLabels,
        'node-group': 'voyager',
        'physical-node': 'rfhome-voyager-1',
        'topology.kubernetes.io/zone': 'rfhome-voyager'
    }
}

export const worker2: NodeDefinition = {
    address: '10.229.97.35',
    hostname: 'pathweb-worker-2',
    role: 'worker',
    schematic: schematics.nocloud.qemu.default,
        labels: {
        ...rfhomeLabels,
        'node-group': 'voyager',
        'physical-node': 'rfhome-voyager-2',
        'topology.kubernetes.io/zone': 'rfhome-voyager'
    }
}

export const worker3: NodeDefinition = {
    address: '10.229.97.36',
    hostname: 'pathweb-worker-3',
    role: 'worker',
    schematic: schematics.nocloud.qemu.default,
    labels: {
        ...rfhomeLabels,
        'node-group': 'voyager',
        'physical-node': 'rfhome-voyager-3',
        'topology.kubernetes.io/zone': 'rfhome-voyager'
    }
}

export const workerBaldric: NodeDefinition = {
    address: '10.229.97.37',
    hostname: 'pathweb-worker-baldric',
    role: 'worker',
    schematic: schematics.nocloud.qemu.default,
    labels: {
        ...rfhomeLabels,
        'node-group': 'voyagbaldricer',
        'physical-node': 'rfhome-baldric',
        'topology.kubernetes.io/zone': 'rfhome-baldric'
    }
}

export const workerBaldric2: NodeDefinition = {
    address: '10.229.97.238',
    hostname: 'pathweb-worker-baldric-2',
    role: 'worker',
    schematic: schematics.nocloud.qemu.default,
    labels: {
        ...rfhomeLabels,
        'node-group': 'voyagbaldricer',
        'physical-node': 'rfhome-baldric',
        'topology.kubernetes.io/zone': 'rfhome-baldric'
    }
}

export const controlplaneNodes = [control1, control2, control3]
export const workerNodes = [
    worker1, worker2, worker3, workerBaldric, workerBaldric2
]
export const clusterNodes = [...controlplaneNodes, ...workerNodes]
