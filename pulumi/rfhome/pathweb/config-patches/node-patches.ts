import * as pulumi from '@pulumi/pulumi'
import { TypedConfigPatch, TypedConfigPatchProvider, v1alpha1Config } from '../types/ConfigPatch';

const talosPathwebConfig = new pulumi.Config('talos-pathweb')
const homelabConfig = new pulumi.Config('homelab')
const harborRegistry = homelabConfig.require('harbor-registry')

export const nodePatches: TypedConfigPatchProvider = () => [
    kubeClusterConfig,
    kubeNodeConfig,
    sysctlConfig,
    kubeSpanConfig,
    kubeletConfig,
    hostDnsConfig,
    kubePrismConfig,
    ...discoveryServiceConfigs,
    kubeNetworkConfig,
    kubeProxyConfig,
    harborRegistryAuthPatch,
    ...registryMirrorsTypedPatches,
    filesystemTrimConfig
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


const kubeClusterConfig: TypedConfigPatch = v1alpha1Config('KubeClusterConfig', {
    clusterName: talosPathwebConfig.require('cluster-name'),
    endpoint: `https://controlplane.${talosPathwebConfig.require('cluster-domain')}:6443`
})

const kubeNodeConfig: TypedConfigPatch = v1alpha1Config('KubeNodeConfig', {
    nodeIP: {
        validSubnets: homelabConfig.requireObject<string[]>('servers-vlan-subnet')
    }
})


const sysctlConfig: TypedConfigPatch = v1alpha1Config('SysctlConfig', {
    params: {
        "kernel.domainname": homelabConfig.require('servers-domain'),
        "net.ipv4.conf.all.rp_filter": 0,
        "user.max_user_namespaces": 11255
    }
})

const kubeSpanConfig: TypedConfigPatch = v1alpha1Config('KubeSpanConfig', {
    enabled: false,
    advertiseKubernetesNetworks: true,
    mtu: 1412
})

const kubeletConfig: TypedConfigPatch = v1alpha1Config('KubeletConfig', {
    config: {
        rotateCertificates: true,
        featureGates: talosPathwebConfig.requireObject<{ [key: string]: boolean }>('kubelet-feature-gates')
    }
})

const hostDnsConfig: TypedConfigPatch = v1alpha1Config('ResolverConfig', {
    hostDNS: {
        enabled: true,
        forwardKubeDNSToHost: true,
        resolveMemberNames: true
    }
})

const kubePrismConfig: TypedConfigPatch = v1alpha1Config('KubePrismConfig', {
    port: 7445,
})

const discoveryServiceConfigs: TypedConfigPatch[] = [
    v1alpha1Config('DiscoveryServiceConfig', {
        name: 'primary',
        endpoint: 'https://discovery.talos.dev/'
    })
]

const kubeNetworkConfig: TypedConfigPatch = v1alpha1Config('KubeNetworkConfig', {
    podSubnets: talosPathwebConfig.requireObject<string[]>('pod-subnets'),
    serviceSubnets: talosPathwebConfig.requireObject<string[]>('service-subnets'),
    nodeCIDRMaskSizeIPv4: 24,
    nodeCIDRMaskSizeIPv6: 64
})

const kubeProxyConfig: TypedConfigPatch = v1alpha1Config('KubeProxyConfig', {
    enabled: false
})

const filesystemTrimConfig: TypedConfigPatch = v1alpha1Config('FilesystemTrimConfig', {
    interval: '168h0m0s'
})
