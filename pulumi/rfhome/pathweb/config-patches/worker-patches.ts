import * as pulumi from '@pulumi/pulumi'
import { ConfigPatch } from '../types/ConfigPatch';

const pathwebConfig = new pulumi.Config('talos-pathweb')

export const workerPatches: ConfigPatch = {
    machine: {
        nodeLabels: {
            role: 'worker'
        },
        network: {
            interfaces: [
                {interface: 'eth0', dhcp: true},
                {interface: 'eth1', dhcp: false},
                {
                    interface: 'iot',
                    dhcp: false,
                    bridge: {
                        interfaces: [
                            'eth1'
                        ]
                    }
                }
            ]
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
