import * as pulumi from '@pulumi/pulumi'
import { ConfigPatch } from '../types/ConfigPatch';

const talosPathwebConfig = new pulumi.Config('talos-pathweb')
const homelabConfig = new pulumi.Config('homelab')
const harborRegistry = homelabConfig.require('harbor-registry')

const registryMirrors: { [key: string]: { overridePath: boolean, endpoints: string[] } } = {}
Object.entries(homelabConfig.requireObject<{[key:string]: string}>('harbor-caches'))
    .forEach(([registry, cacheProject]) => {
        const upstream = registry == 'docker.io' ?
            'https://registry.hub.docker.com/v2/' :
            `https://${registry}/v2/`
        const cacheUrl = `https://${harborRegistry}/v2/${cacheProject}/`
        registryMirrors[registry] = {
            overridePath: true,
            endpoints: [
                cacheUrl,
                upstream
            ]
        }
    })


export const nodePatches: ConfigPatch = {
    machine: {
        sysctls: {
            "kernel.domainname": homelabConfig.require('servers-domain'),
            "net.ipv4.conf.all.rp_filter": 0,
            "user.max_user_namespaces": 11255
        },
        network: {
            kubespan: {
                enabled: false
            }
        },
        kubelet: {
            clusterDNS: ["10.97.0.10", "fd96:619:6b75:120::a"],
            nodeIP: {
                validSubnets: homelabConfig.requireObject<string[]>('servers-vlan-subnet')
            },
            extraArgs: {
                "rotate-server-certificates": true
            },
            extraConfig: {
                featureGates: talosPathwebConfig.requireObject<{[key: string]: boolean}>('kubelet-feature-gates')
            }
        },
        features: {
            hostDNS: {
                enabled: true,
                forwardKubeDNSToHost: false
            },
            kubePrism: {
                enabled: true,
                port: 7445
            }
        },
        registries: {
            mirrors: registryMirrors,
            config: {
                [harborRegistry]: {
                    auth: {
                        username: talosPathwebConfig.require("rfhome-harbor-username"),
                        password: talosPathwebConfig.require("rfhome-harbor-password")
                    }
                }
            }
        }
    },
    cluster: {
        discovery: {
            enabled: true
        },
        controlPlane: {
            endpoint: `https://controlplane.${talosPathwebConfig.require('cluster-domain')}:6443`
        },
        network: {
            cni: {
                name: "none"
            },
            podSubnets: talosPathwebConfig.requireObject<string[]>('pod-subnets'),
            serviceSubnets: talosPathwebConfig.requireObject<string[]>('service-subnets'),
        },
        proxy: {
            disabled: true
        }
    }
}
