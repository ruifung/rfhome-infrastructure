import * as pulumi from '@pulumi/pulumi';
import { factoryImageRegistry } from '../talos-version';
import { ConfigPatchOutput, ConfigPatchProvider, ConfigPatch, TypedConfigPatchOutput, v1alpha1Config } from '../types/ConfigPatch';
import { NodeDefinition } from '../types/NodeDefinition';
import { Type } from '@pulumi/aws/appsync';
import { v1alpha1 } from '@pulumi/kubernetes/admissionregistration';

const pathwebConfig = new pulumi.Config('talos-pathweb')
const homelabConfig = new pulumi.Config('homelab')

const clusterDomain = pathwebConfig.require('cluster-domain')
const serverDomain = homelabConfig.require('servers-domain')

export const nodeSpecificPatches: ConfigPatchProvider = (node: NodeDefinition) => {
    const installerImage = pulumi.interpolate`${factoryImageRegistry}/installer/${node.schematic.id}:${pathwebConfig.require('talos-version')}`
    return [
        nodeSpecificMachineconfigPatch(node),
        v1alpha1Config('HostnameConfig', { hostname: node.hostname, auto: 'off' })
    ]
}

function nodeSpecificMachineconfigPatch(node: NodeDefinition): ConfigPatch {
    const installerImage = pulumi.interpolate`${factoryImageRegistry}/installer/${node.schematic.id}:${pathwebConfig.require('talos-version')}`
    return installerImage.apply(image => ({
        machine: {
            nodeLabels: node.labels ?? {},
            certSANs: [
                `${node.hostname}.${serverDomain}`,
            ].filter(it => it != null),
            install: {
                image: image
            }
        }
    }))
}
