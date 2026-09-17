import * as pulumi from '@pulumi/pulumi';
import { factoryImageRegistry } from '../talos-version';
import { ConfigPatchProvider, v1alpha1Config, TypedConfigPatchProvider } from '../types/ConfigPatch';
import { NodeDefinition } from '../types/NodeDefinition';

const pathwebConfig = new pulumi.Config('talos-pathweb')
const homelabConfig = new pulumi.Config('homelab')

const clusterDomain = pathwebConfig.require('cluster-domain')
const serverDomain = homelabConfig.require('servers-domain')

export const nodeSpecificPatches: ConfigPatchProvider = (node: NodeDefinition) => {
    return [
        ...nodeSpecificMachineconfigPatch(node),
        v1alpha1Config('HostnameConfig', { hostname: node.hostname, auto: 'off' }),
        ...unattendedInstallConfig(node),
    ]
}

const nodeSpecificMachineconfigPatch: ConfigPatchProvider = (node) => {
    return [
        {
            machine: {
                certSANs: [
                    `${node.hostname}.${serverDomain}`,
                ].filter(it => it != null),
            }
        },
        v1alpha1Config('KubeNodeConfig', {
            labels: node.labels ?? {},
        })
    ]
}

const unattendedInstallConfig: TypedConfigPatchProvider = (node: NodeDefinition) => {
    const installerImage = pulumi.interpolate`${factoryImageRegistry}/installer/${node.schematic.id}:${pathwebConfig.require('talos-version')}`
    return [
        installerImage.apply(image => {
            return v1alpha1Config('UnattendedInstallConfig', {
                installer: {
                    image: image,
                }
            })
        })
    ]
}
