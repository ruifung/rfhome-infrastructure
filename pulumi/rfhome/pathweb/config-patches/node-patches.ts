import * as pulumi from '@pulumi/pulumi'
import { ConfigPatch, ConfigPatchProvider, TypedConfigPatch, v1alpha1Config } from '../types/ConfigPatch';

const talosPathwebConfig = new pulumi.Config('talos-pathweb')
const homelabConfig = new pulumi.Config('homelab')
const harborRegistry = homelabConfig.require('harbor-registry')

export const nodePatches: ConfigPatchProvider = () => [
    nodeMachineconfigPatch,
    harborRegistryAuthPatch,
    ...registryMirrorsTypedPatches,
]

const harborRegistryAuthPatch: TypedConfigPatch = v1alpha1Config('RegistryAuthConfig', {
    name: harborRegistry,
    username: talosPathwebConfig.require("rfhome-harbor-username"),
    password: talosPathwebConfig.require("rfhome-harbor-password")
});

const registryMirrorsTypedPatches: TypedConfigPatch[] =
    Object.entries(homelabConfig.requireObject<{ [key: string]: string }>('harbor-caches'))
        .map(([registry, cacheProject]) => {
            const upstream = registry == 'docker.io' ?
                'https://registry.hub.docker.com/v2/' :
                `https://${registry}/v2/`
            const cacheUrl = `https://${harborRegistry}/v2/${cacheProject}/`
            return v1alpha1Config('RegistryMirrorConfig', {
                name: registry,
                endpoints: [
                    { url: cacheUrl, overridePath: true },
                ],
                skipFallback: false
            })
        });

const nodeMachineconfigPatch: ConfigPatch = {
    machine: {
        sysctls: {
            "kernel.domainname": homelabConfig.require('servers-domain'),
            "net.ipv4.conf.all.rp_filter": 0,
            "user.max_user_namespaces": 11255
        },
        network: {
            kubespan: {
                enabled: false,
                advertiseKubernetesNetworks: true,
                mtu: 1412
            }
        },
        kubelet: {
            nodeIP: {
                validSubnets: homelabConfig.requireObject<string[]>('servers-vlan-subnet')
            },
            extraArgs: {
                "rotate-server-certificates": true
            },
            extraConfig: {
                featureGates: talosPathwebConfig.requireObject<{ [key: string]: boolean }>('kubelet-feature-gates')
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
