import * as pulumi from '@pulumi/pulumi'
import { ConfigPatch, ConfigPatchProvider, TypedConfigPatch, v1alpha1Config } from '../types/ConfigPatch';

const pathwebConfig = new pulumi.Config('talos-pathweb')

export const workerPatches: ConfigPatchProvider = () => [
    workerMachineconfigPatch,
    kubeNodeConfig,
    sysctlConfig,
    ...workerNodeNetworkConfigs
]

const workerNodeNetworkConfigs: TypedConfigPatch[] = [
    // The primary interface
    v1alpha1Config('LinkConfig', { name: 'eth0', up: true }),
    v1alpha1Config('DHCPv4Config', { name: 'eth0', clientIdentifier: 'mac' }),
    v1alpha1Config('DHCPv6Config', { name: 'eth0', clientIdentifier: 'mac' }),
    // IoT VLAN and associated bridge for attaching to using Multus CNI.
    v1alpha1Config('LinkConfig', { name: 'eth1', up: true }),
    v1alpha1Config('BridgeConfig', { name: 'iot', links: ['eth1'] }),
    // Storage VLAN for worker nodes
    v1alpha1Config('LinkConfig', { name: 'eth2', up: true }),
    v1alpha1Config('DHCPv4Config', { name: 'eth2', clientIdentifier: 'mac' }),
    // LAN VLAN and associated bridge for attaching to using Multus CNI.
    v1alpha1Config('LinkConfig', { name: 'eth3', up: true }),
    v1alpha1Config('BridgeConfig', { name: 'homelan', links: ['eth3'] })
]

const kubeNodeConfig: TypedConfigPatch = v1alpha1Config('KubeNodeConfig', {
    labels: {
        role: 'worker'
    }
})

const sysctlConfig: TypedConfigPatch = v1alpha1Config('SysctlConfig', {
    params: {
        'net.ipv6.conf.eth1.accept_ra': '0',
        'net.ipv6.conf.default.accept_ra': '0',
        'net.ipv6.conf.iot.accept_ra': '0',
        'net.ipv4.conf.all.arp_announce': '2'
    }
})

const workerMachineconfigPatch: ConfigPatch = {
    machine: {
        certSANs: [ `*.workers.${pathwebConfig.require('cluster-domain')}` ],
    }
}
