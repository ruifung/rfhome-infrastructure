import * as pulumi from '@pulumi/pulumi'
import { control1, control2, control3 } from "../talos-nodes"
import { ConfigPatch } from '../types/ConfigPatch'

const pathwebConfig = new pulumi.Config('talos-pathweb')
const homelabConfig = new pulumi.Config('homelab')

export const everywhereSubnets = [
    {subnet: '0.0.0.0/0'},
    {subnet: '::/0'}
]

export const serverVlan = homelabConfig.requireObject<string[]>('servers-vlan-subnet').map(subnet => ({subnet}))
export const podIpSubnets = pathwebConfig.requireObject<string[]>('pod-subnets').map(subnet => ({subnet}))

export const controlplaneNodeIps = [
    {subnet: `${control1.address}/32`},
    {subnet: `${control2.address}/32`},
    {subnet: `${control3.address}/32`}
]

function ingressNetworkRule(rule: {
    name: string,
    ports: (number|string)[],
    protocol: 'tcp'|'udp',
    ingress: {subnet: string}[]
}): ConfigPatch { return {
    apiVersion: 'v1alpha1',
    kind: 'NetworkRuleConfig',
    name: rule.name,
    portSelector: {
        ports: rule.ports,
        protocol: rule.protocol
    },
    ingress: rule.ingress
}}

export const controlplaneFirewall: ConfigPatch[] = [
    {
        apiVersion: 'v1alpha1',
        kind: 'NetworkDefaultActionConfig',
        ingress: 'block'
    },
    ingressNetworkRule({
        name: 'kubelet-ingress',
        ports: [10250],
        protocol: 'tcp',
        ingress: [...serverVlan, ...podIpSubnets]
    }),
    ingressNetworkRule({
        name: 'apid-ingress',
        ports: [50000],
        protocol: 'tcp',
        ingress: [...everywhereSubnets]
    }),
    ingressNetworkRule({
        name: 'trustd-ingress',
        ports: [50001],
        protocol: 'tcp',
        ingress: [...serverVlan]
    }),
    ingressNetworkRule({
        name: 'kubernetes-api-ingress',
        ports: [6443],
        protocol: 'tcp',
        ingress: [...everywhereSubnets]
    }),
    ingressNetworkRule({
        name: 'etcd-ingress',
        ports: [2379,2380],
        protocol: 'tcp',
        ingress: [...controlplaneNodeIps]
    }),
    ingressNetworkRule({
        name: 'controlplane-metrics',
        ports: [2381, 10257, 10259],
        protocol: 'tcp',
        ingress: [...serverVlan, ...podIpSubnets]
    }),
    ingressNetworkRule({
        name: 'cilium-metrics',
        ports: ['9962-9965'],
        protocol: "tcp",
        ingress: [...serverVlan, ...podIpSubnets]
    }),
    ingressNetworkRule({
        name: 'node-metrics',
        ports: [9100],
        protocol: "tcp",
        ingress: [...serverVlan, ...podIpSubnets]
    }),
    ingressNetworkRule({
        name: 'cilium-geneve',
        ports: [6081],
        protocol: "udp",
        ingress: [...serverVlan]
    }),
    ingressNetworkRule({
        name: 'cilium-health',
        ports: [4240],
        protocol: "tcp",
        ingress: [...serverVlan]
    }),
    ingressNetworkRule({
        name: 'cilium-hubble',
        ports: [4244, 4245],
        protocol: "tcp",
        ingress: [...serverVlan]
    }),
    ingressNetworkRule({
        name: 'cilium-mtls',
        ports: [4250],
        protocol: "tcp",
        ingress: [...serverVlan]
    }),
    ingressNetworkRule({
        name: 'kubespan-wg',
        ports: [51820],
        protocol: "udp",
        ingress: [...everywhereSubnets]
    }),
    // ingressNetworkRule({
    //     name: 'cilium-clustermesh',
    //     ports: [32379],
    //     protocol: 'tcp',
    //     ingress: [...everywhereSubnets]
    // })
]
