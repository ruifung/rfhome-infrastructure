import { Config } from '@pulumi/pulumi';
import { ConfigPatch, ConfigPatchProvider, TypedConfigPatch, TypedConfigPatchProvider, v1alpha1Config } from '../types/ConfigPatch';

const talosPathwebConfig = new Config('talos-pathweb')
const homelabConfig = new Config('homelab')
const serverDomain = homelabConfig.require('servers-domain')
const clusterDomain = talosPathwebConfig.require('cluster-domain')

export const controlplanePatches: ConfigPatchProvider = (node) => [
    controlplaneMachineconfigPatch,
    ...controlplaneNodeNetworkConfig,
    ...kubeApiServerConfig(node),
    kubeAdmissionControlConfig,
    kubeControllerManagerConfig,
    kubeSchedulerConfig,
    kubeCoreDNSConfig,
    ...kubeExternalManifestsConfig,
]

const controlplaneNodeNetworkConfig: TypedConfigPatch[] = [
    v1alpha1Config('KubeNodeConfig', { labels: { role: 'control-plane' } }),
    v1alpha1Config('LinkConfig', { name: 'eth0', up: true }),
    v1alpha1Config('DHCPv4Config', { name: 'eth0', clientIdentifier: 'mac' }),
    v1alpha1Config('DHCPv6Config', { name: 'eth0', clientIdentifier: 'mac' }),
    v1alpha1Config('Layer2VIPConfig', { name: talosPathwebConfig.require('cluster-vip'), link: 'eth0' })
]

const apiServerFeatureGatesArg = Object.entries(talosPathwebConfig.requireObject<{[key: string]: boolean}>('api-server-feature-gates'))
    .map(([name, value]) => `${name}=${value}`)
    .join(',');

const kubeApiServerConfig: TypedConfigPatchProvider = (node) => {
    return [v1alpha1Config('KubeAPIServerConfig', {
        extraArgs: {
            'feature-gates': apiServerFeatureGatesArg
        },
        certExtraSANs: [
            `${node.hostname}.${serverDomain}`,
            `controlplane.${clusterDomain}`,
            `*.controlplane.${clusterDomain}`
        ],
        resources: {
            requests: {
                cpu: '500m',
                memory: '1.5Gi'
            }
        }
    })]
}

const kubeAdmissionControlConfig: TypedConfigPatch = v1alpha1Config('KubeAdmissionControlConfig', {
    name: 'PodSecurity',
    configuration: {
        apiVersion: 'pod-security.admission.config.k8s.io/v1alpha1',
        kind: 'PodSecurityConfiguration',
        defaults: {
            'audit': 'restricted',
            'audit-version': 'latest',
            'enforce': 'baseline',
            'enforce-version': 'latest',
            'warn': 'restricted',
            'warn-version': 'latest'
        },
        exemptions: {
            namespaces: [],
            runtimeClasses: [],
            usernames: []
        }
    }
})

const kubeControllerManagerConfig: TypedConfigPatch = v1alpha1Config('KubeControllerManagerConfig', {
    extraArgs: {
        "bind-address": "0.0.0.0"
    },
    resources: {
        requests: {
            cpu: '100m',
            memory: '200Mi'
        }
    }
})

const kubeSchedulerConfig: TypedConfigPatch = v1alpha1Config('KubeSchedulerConfig', {
    extraArgs: {
        "bind-address": "0.0.0.0"
    }
})

const kubeCoreDNSConfig: TypedConfigPatch = v1alpha1Config('KubeCoreDNSConfig', {
    enabled: false
})

const kubeExternalManifestsConfig: TypedConfigPatch[] = [
    v1alpha1Config('KubeExternalManifestConfig', {
        url: "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml"
    }),
    v1alpha1Config('KubeExternalManifestConfig', {
        url: "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
    })
]

const controlplaneMachineconfigPatch: ConfigPatch = {
    machine: {
        certSANs: [
            `controlplane.${clusterDomain}`,
            `*.controlplane.${clusterDomain}`
        ]
    },
    cluster: {
        // clusterName: talosPathwebConfig.require('cluster-name'),
        etcd: {
            extraArgs: {
                "election-timeout": "5000",
                "listen-metrics-urls": "http://0.0.0.0:2381"
            }
        }
    }
}
