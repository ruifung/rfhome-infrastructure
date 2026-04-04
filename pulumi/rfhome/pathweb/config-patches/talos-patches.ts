import * as pulumi from '@pulumi/pulumi'
import { Output } from '@pulumi/pulumi'
import { nodePatches } from './node-patches'
import { containersSeccompPatch } from './seccomp-profiles'
import { controlplaneFirewall } from './controlplane-firewall'
import { controlplanePatches } from './controlplane-patches'
import { watchdogPatch } from './watchdog'
import { workerPatches } from './worker-patches'
import { nodeSpecificPatches } from './node-specific-patch'
import { NodeDefinition } from '../types/NodeDefinition'
import { ConfigPatch, ConfigPatchProvider } from '../types/ConfigPatch'
import { coreDnsConfigPatch } from './coredns-custom'
import { userspaceOomPatch } from './talos-oom'


export function getNodePatches(node: NodeDefinition): Output<ConfigPatch>[] {
    const patchProviders: ConfigPatchProvider[] = [
        nodePatches,
        watchdogPatch,
        userspaceOomPatch,
        containersSeccompPatch,
        coreDnsConfigPatch,
        nodeSpecificPatches
    ]

    if (node.role == 'controlplane') {
        patchProviders.push(
            controlplanePatches,
            controlplaneFirewall
        )
    } else {
        patchProviders.push(
            workerPatches
        )
    }

    return patchProviders
        .flatMap(provider => provider(node))
        .map(patch => pulumi.output(patch))
}
