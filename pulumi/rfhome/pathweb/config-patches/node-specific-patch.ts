import { factoryImageRegistry } from '../talos-version';
import { ConfigPatch } from '../types/ConfigPatch';
import { NodeDefinition } from '../types/NodeDefinition';
import * as pulumi from '@pulumi/pulumi'

const pathwebConfig = new pulumi.Config('talos-pathweb')
const homelabConfig = new pulumi.Config('homelab')

const clusterDomain = pathwebConfig.require('cluster-domain')
const serverDomain = homelabConfig.require('servers-domain')

export function generateNodeSpecificPatches(node: NodeDefinition): pulumi.Output<ConfigPatch> {
    const clusterNodeDomain = node.role == "controlplane" ?
        `controlplane.${clusterDomain}` :
        `workers.${clusterDomain}`

    const installerImage = pulumi.interpolate`${factoryImageRegistry}/installer/${node.schematic.id}:${pathwebConfig.require('talos-version')}`
    return installerImage.apply( image => ({
        machine: {
            nodeLabels: node.labels ?? {},
            certSANs: [
                `${node.hostname}.${serverDomain}`,
                `${node.hostname}.${clusterNodeDomain}`,
                node.role == 'controlplane' ? `controlplane.${clusterDomain}` : null
            ].filter(it => it != null),
            network: {
                hostname: node.hostname
            },
            install: {
                image: image
            }
        }
    }))
}
