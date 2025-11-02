import { Input } from '@pulumi/pulumi'
import { nodePatches } from './node-patches'
import { containersSeccompPatch } from './seccomp-profiles'
import { controlplaneFirewall } from './controlplane-firewall'
import { controlplanePatches } from './controlplane-patches'
import { watchdogPatch } from './watchdog'
import { workerPatches } from './worker-patches'
import { generateNodeSpecificPatches } from './node-specific-patch'
import { NodeDefinition } from '../types/NodeDefinition'
import { ConfigPatch } from '../types/ConfigPatch'
import { coreDnsConfigPatch } from './coredns-custom'


export function getNodePatches(node: NodeDefinition) {
    const patches: Input<ConfigPatch>[] = [
        nodePatches,
        watchdogPatch,
        containersSeccompPatch,
        coreDnsConfigPatch
    ]

    if (node.role == 'controlplane') {
        patches.push(
            controlplanePatches,
            ...controlplaneFirewall
        )
    } else {
        patches.push(
            workerPatches
        )
    }

    patches.push(generateNodeSpecificPatches(node))

    for (const patch of patches) {
        if (patch == undefined) {
            throw "Undefined patch detected."
        }
    }

    return patches
}
