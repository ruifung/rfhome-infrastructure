import { pathwebControl2VM } from "./node-vms/proxmox-control-2";
import { pathwebControl3VM } from "./node-vms/proxmox-control-3";
import { generateMachineConfiguration, pathwebClusterParent, secrets } from "./talos-machineconfig";
import { control1, control2, control3, controlplaneNodes } from "./talos-nodes";
import * as talos from '@pulumiverse/talos'
import * as pulumi from '@pulumi/pulumi'
import * as k8s from '@pulumi/kubernetes'
import * as forgejo from '@pulumi/forgejo'
import * as tls from '@pulumi/tls'
import * as command from '@pulumi/command'
import { pathwebControl1VM } from "./node-vms/proxmox-control-1";

const pathwebConfig = new pulumi.Config('talos-pathweb')
const homelabConfig = new pulumi.Config('homelab')
const serverDomain = homelabConfig.require('servers-domain')

const controlPlaneVms = {
    [control1.hostname]: pathwebControl1VM,
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
    }, { dependsOn: [vm] })

    controlPlaneApply.push(configApply)
}

const talosBootstrap = new talos.machine.Bootstrap('pathweb-cluster-bootstrap', {
    clientConfiguration: secrets.clientConfiguration,
    node: controlPlaneApply[0].node
}, { parent: pathwebClusterParent, dependsOn: [controlPlaneApply[0]] })

const talosKubeConfig = new talos.cluster.Kubeconfig('pathweb-talos-kubeconfig', {
    clientConfiguration: secrets.clientConfiguration,
    node: `controlplane.${pathwebConfig.require('cluster-domain')}`
}, { parent: pathwebClusterParent, dependsOn: [...controlPlaneApply, talosBootstrap] })

const provider = new k8s.Provider('pathweb-k8s', {
    kubeconfig: talosKubeConfig.kubeconfigRaw
}, { parent: pathwebClusterParent })
export const pathwebK8sProvider = provider

// Install Cilium CNI
const ciliumValuesFile = new pulumi.asset.FileAsset('rfhome/pathweb/cilium-values.yaml')
new k8s.helm.v3.Release("pathweb-cilium", {
    name: 'cilium',
    repositoryOpts: {
        repo: 'https://helm.cilium.io/'
    },
    chart: 'cilium',
    version: `v${pathwebConfig.require('cilium-version')}`,
    valueYamlFiles: [ciliumValuesFile],
    namespace: 'kube-system'
}, { provider, parent: provider })

// Install CoreDNS (To allow customization of coredns configuration)
const coreDnsValuesFile = new pulumi.asset.FileAsset('rfhome/pathweb/coredns-values.yaml')
new k8s.helm.v3.Release("pathweb-coredns", {
    name: 'coredns',
    chart: 'oci://ghcr.io/coredns/charts/coredns',
    version: pathwebConfig.require('coredns-version'),
    valueYamlFiles: [coreDnsValuesFile],
    namespace: 'kube-system'
}, { provider, parent: provider })

// Bootstrap the flux operator, it'll manage itself ater this.
const fluxOperator = new k8s.helm.v3.Release("pathweb-flux-operator", {
    name: 'flux-operator',
    namespace: 'flux-system',
    createNamespace: true,
    chart: 'oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator'
}, { provider, parent: provider, ignoreChanges: ['version', 'chart'] })

// new github.RepositoryDeployKey('pathweb-flux-deploy-key', {
//     title: 'Pathweb FluxCD Deploy Key',
//     repository: 'ruifung/rfhome-infrastructure',
//     key: ''
// })

const deployKey = new tls.PrivateKey('pathweb-flux-deploy-key', {
    algorithm: 'ED25519'
}, { parent: pathwebClusterParent })

const gitopsRepo = forgejo.getRepositoryOutput({
    owner: { login: 'rf-homelab' },
    name: 'infrastructure-gitops'
})

const privateGitopsRepo = forgejo.getRepositoryOutput({
    owner: { login: 'rf-homelab' },
    name: 'infrastructure-gitops-private'
})

const sshKeyScan = new command.local.Command('rfhome-git-keyscan', {
    create: `ssh-keyscan -t ed25519 -p ${homelabConfig.require('local-git-ssh-port')} ${homelabConfig.require('local-git-ssh-host')}`
}, {parent: deployKey})

const k8sSecret = new k8s.core.v1.Secret('flux-gitops-key-secret', {
    metadata: {
        name: 'rfhome-gitops-key',
        namespace: 'flux-system'
    },
    stringData: {
        identity: deployKey.privateKeyOpenssh,
        'identity.pub': deployKey.publicKeyOpenssh,
        known_hosts: sshKeyScan.stdout.apply(str => str.replace('\r', ''))
    }
}, {parent: deployKey, dependsOn: [fluxOperator]})

const deployKeys = [
    new forgejo.DeployKey('pathweb-gitops-key', {
        repositoryId: gitopsRepo.id,
        key: deployKey.publicKeyOpenssh,
        readOnly: true,
        title: 'Pathweb FluxCD GitOps Deploy Key',
    }, {parent: deployKey, deleteBeforeReplace: true, ignoreChanges: ['*']}),
    new forgejo.DeployKey('pathweb-private-gitops-key', {
        repositoryId: privateGitopsRepo.id,
        key: deployKey.publicKeyOpenssh,
        readOnly: true,
        title: 'Pathweb FluxCD GitOps Deploy Key'
    }, {parent: deployKey, deleteBeforeReplace: true, ignoreChanges: ['*']})
]

const fluxInstance = new k8s.yaml.ConfigFile('pathweb-flux-instance', {
        file: '../clusters/pathweb/flux-instance.yaml',
        skipAwait: true
    }, { dependsOn: [fluxOperator] })
