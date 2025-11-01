import { pathwebControl2VM } from "./node-vms/proxmox-control-2";
import { pathwebControl3VM } from "./node-vms/proxmox-control-3";
import { generateMachineConfiguration, pathwebClusterParent, secrets } from "./talos-machineconfig";
import { control2, control3, controlplaneNodes } from "./talos-nodes";
import * as talos from '@pulumiverse/talos'
import * as pulumi from '@pulumi/pulumi'
import * as k8s from '@pulumi/kubernetes'

const pathwebConfig = new pulumi.Config('talos-pathweb')
const homelabConfig = new pulumi.Config('homelab')
const serverDomain = homelabConfig.require('servers-domain')

const controlPlaneVms = {
    [control2.hostname]: pathwebControl2VM,
    [control3.hostname]: pathwebControl3VM,
}

const controlPlaneApply = []
for (const node of controlplaneNodes) {
    const vm = controlPlaneVms[node.hostname]

    const configApply = new talos.machine.ConfigurationApply(`talos-apply-pathweb-${node.hostname}`, {
        clientConfiguration: secrets.clientConfiguration,
        machineConfigurationInput: generateMachineConfiguration(node).machineConfiguration,
        applyMode: 'auto',
        node: `${node.hostname}.${serverDomain}`,
    }, {dependsOn: [vm]})

    controlPlaneApply.push(configApply)
}

const talosBootstrap = new talos.machine.Bootstrap('pathweb-cluster-bootstrap', {
    clientConfiguration: secrets.clientConfiguration,
    node: controlPlaneApply[0].node
}, {parent: pathwebClusterParent ,dependsOn: [controlPlaneApply[0]]})

const talosKubeConfig = new talos.cluster.Kubeconfig('pathweb-talos-kubeconfig', {
    clientConfiguration: secrets.clientConfiguration,
    node: `controlplane.${pathwebConfig.require('cluster-domain')}`
}, {parent: pathwebClusterParent, dependsOn: [...controlPlaneApply, talosBootstrap]})

const provider = new k8s.Provider('pathweb-k8s', {
    kubeconfig: talosKubeConfig.kubeconfigRaw
}, {parent: pathwebClusterParent})
const ciliumValuesFile = new pulumi.asset.FileAsset('rfhome/pathweb/cilium-values.yaml')
const ciliumRelease = new k8s.helm.v3.Release("pathweb-cilium", {
    name: 'cilium',
    repositoryOpts: {
        repo: 'https://helm.cilium.io/'
    },
    chart: 'cilium',
    version: `v${pathwebConfig.require('cilium-version')}`,
    valueYamlFiles: [ciliumValuesFile],
    namespace: 'kube-system'
}, {provider, parent: provider})

const coreDnsValuesFile = new pulumi.asset.FileAsset('rfhome/pathweb/coredns-values.yaml')
const coreDnsRelease = new k8s.helm.v3.Release("pathweb-coredns", {
    name: 'coredns',
    chart: 'oci://harbor.services.home.yrf.me/ghcr/coredns/charts/coredns',
    version: pathwebConfig.require('coredns-version'),
    valueYamlFiles: [coreDnsValuesFile],
    namespace: 'kube-system'
}, {provider, parent: provider})
