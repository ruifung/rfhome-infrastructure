import { Config } from '@pulumi/pulumi';
import { controlplaneNodes } from '../talos-nodes';
import { ConfigPatch, ConfigPatchProvider, TypedConfigPatchProvider, v1alpha1Config } from '../types/ConfigPatch';

const talosPathwebConfig = new Config('talos-pathweb')
const homelabConfig = new Config('homelab')
const serverDomain = homelabConfig.require('servers-domain')
const clusterDomain = talosPathwebConfig.require('cluster-domain')

export const controlplanePatches: ConfigPatchProvider = () => [
    controlplaneMachineconfigPatch,
    v1alpha1Config('LinkConfig', { name: 'eth0', up: true }),
    v1alpha1Config('DHCPv4Config', { name: 'eth0', clientIdentifier: 'mac' }),
    v1alpha1Config('DHCPv6Config', { name: 'eth0', clientIdentifier: 'mac' }),
    v1alpha1Config('Layer2VIPConfig', { name: talosPathwebConfig.require('cluster-vip'), link: 'eth0' })
]

const apiServerFeatureGatesArg = Object.entries(talosPathwebConfig.requireObject<{[key: string]: boolean}>('api-server-feature-gates'))
    .map(([name, value]) => `${name}=${value}`)
    .join(',');

const controlplaneMachineconfigPatch: ConfigPatch = {
    machine: {
        nodeLabels: {
            role: 'control-plane'
        },
        certSANs: [
            `controlplane.${clusterDomain}`,
            `*.controlplane.${clusterDomain}`
        ]
    },
    cluster: {
        clusterName: talosPathwebConfig.require('cluster-name'),
        apiServer: {
            extraArgs: {
                'feature-gates': apiServerFeatureGatesArg
            },
            certSANs: [
                ...controlplaneNodes.map(node => `${node.hostname}.${serverDomain}`)
            ],
            admissionControl: [
                {
                    name: 'PodSecurity',
                    configuration: {
                        kind: 'PodSecurityConfiguration',
                        exemptions: {
                            namespaces: [],
                            runtimeClasses: [],
                            usernames: []
                        }
                    }
                }
            ],
            resources:{
                requests: {
                    cpu: '500m',
                    memory: '1.5Gi'
                }
            }
        },
        controllerManager: {
            extraArgs: {
                "bind-address": "0.0.0.0"
            },
            resources: {
                requests: {
                    cpu: '100m',
                    memory: '200Mi'
                }
            }
        },
        scheduler: {
            extraArgs: {
                "bind-address": "0.0.0.0"
            }
        },
        etcd: {
            extraArgs: {
                "election-timeout": "5000",
                "listen-metrics-urls": "http://0.0.0.0:2381"
            }
        },
        coreDNS: {
            disabled: true
        },
        extraManifests: [
            "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml",
            "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
        ]
    }
}
