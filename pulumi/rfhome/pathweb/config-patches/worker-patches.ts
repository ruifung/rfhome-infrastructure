import * as pulumi from '@pulumi/pulumi'
import { ConfigPatch, ConfigPatchProvider, v1alpha1Config } from '../types/ConfigPatch';

const pathwebConfig = new pulumi.Config('talos-pathweb')

export const workerPatches: ConfigPatchProvider = () => [
    workerMachineconfigPatch,
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

const workerMachineconfigPatch: ConfigPatch = {
    machine: {
        nodeLabels: {
            role: 'worker'
        },
        certSANs: [ `*.workers.${pathwebConfig.require('cluster-domain')}` ],
        sysctls: {
            'net.ipv6.conf.eth1.accept_ra': '0',
            'net.ipv6.conf.default.accept_ra': '0',
            'net.ipv6.conf.iot.accept_ra': '0',
            'net.ipv4.conf.all.arp_announce': '2'
        }
    }
}
