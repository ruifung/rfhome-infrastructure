import * as command from '@pulumi/command';
import * as forgejo from '@pulumi/forgejo';
import * as k8s from '@pulumi/kubernetes';
import * as pulumi from '@pulumi/pulumi';
import * as tls from '@pulumi/tls';
import * as talos from '@pulumiverse/talos';
import { pathwebControl1VM } from "./node-vms/proxmox-control-1";
import { pathwebControl2VM } from "./node-vms/proxmox-control-2";
import { pathwebControl3VM } from "./node-vms/proxmox-control-3";
import { generateMachineConfiguration, pathwebClusterParent, secrets } from "./talos-machineconfig";
import { control1, control2, control3, controlplaneNodes, workerNodes } from "./talos-nodes";

const pathwebConfig = new pulumi.Config('talos-pathweb')
const homelabConfig = new pulumi.Config('homelab')
const serverDomain = homelabConfig.require('servers-domain')

const controlPlaneVms = {
    [control1.hostname]: pathwebControl1VM,
    [control2.hostname]: pathwebControl2VM,
    [control3.hostname]: pathwebControl3VM,
}

// Apply configurations to control plane nodes
const controlPlaneApply = []
for (const node of controlplaneNodes) {
    const vm = controlPlaneVms[node.hostname]

    const configApply = new talos.machine.ConfigurationApply(`talos-apply-pathweb-${node.hostname}`, {
        clientConfiguration: secrets.clientConfiguration,
        machineConfigurationInput: generateMachineConfiguration(node).machineConfiguration,
        applyMode: 'auto',
        node: `${node.hostname}.${serverDomain}`,
    }, { dependsOn: [vm], deletedWith: vm, parent: vm, aliases: [{parent: pulumi.rootStackResource}] })

    controlPlaneApply.push(configApply)
}

// Bootstrap the talos cluster
const talosBootstrap = new talos.machine.Bootstrap('pathweb-cluster-bootstrap', {
    clientConfiguration: secrets.clientConfiguration,
    node: controlPlaneApply[0].node
}, { parent: pathwebClusterParent, dependsOn: [...controlPlaneApply] })

// Apply configurations to worker nodes
for (const node of workerNodes) {
    new talos.machine.ConfigurationApply(`talos-apply-pathweb-${node.hostname}`, {
        clientConfiguration: secrets.clientConfiguration,
        machineConfigurationInput: generateMachineConfiguration(node).machineConfiguration,
        applyMode: 'auto',
        node: `${node.hostname}.${serverDomain}`,
        endpoint: `controlplane.${pathwebConfig.require('cluster-domain')}` // Worker nodes can't be contacted directly.
    }, {parent: pathwebClusterParent, dependsOn: [talosBootstrap], aliases: [{parent: pulumi.rootStackResource}]})
}

// Generate a kubeconfig for provisioning K8S resources
const talosKubeConfig = new talos.cluster.Kubeconfig('pathweb-talos-kubeconfig', {
    clientConfiguration: secrets.clientConfiguration,
    node: `controlplane.${pathwebConfig.require('cluster-domain')}`
}, { parent: pathwebClusterParent, dependsOn: [...controlPlaneApply, talosBootstrap] })

// Instantiate a k8s provider using the generated kubeconfig
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

// Generate a new ED25519 Private Key for Flux
const deployKey = new tls.PrivateKey('pathweb-flux-deploy-key', {
    algorithm: 'ED25519'
}, { parent: pathwebClusterParent })

// Grab the repository IDs
const gitopsRepo = forgejo.getRepositoryOutput({owner: { login: 'rf-homelab' }, name: 'infrastructure-gitops'})
const privateGitopsRepo = forgejo.getRepositoryOutput({owner: { login: 'rf-homelab' }, name: 'infrastructure-gitops-private'})

// Invoke ssh-keyscan to prepare the known_hosts content for FluxCD
const sshKeyScan = new command.local.Command('rfhome-git-keyscan', {
    create: `ssh-keyscan -t ed25519 -p ${homelabConfig.require('local-git-ssh-port')} ${homelabConfig.require('local-git-ssh-host')}`
}, { parent: deployKey })

// Create a K8S secret for the fluxcd sync
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
}, { parent: deployKey, dependsOn: [fluxOperator] })

// Create deploy keys in Forgejo using the previously generated private key
const deployKeys = [
    new forgejo.DeployKey('pathweb-gitops-key', {
        repositoryId: gitopsRepo.id,
        key: deployKey.publicKeyOpenssh,
        readOnly: true,
        title: 'Pathweb FluxCD GitOps Deploy Key',
    }, { parent: deployKey, deleteBeforeReplace: true, ignoreChanges: ['*'] }),
    new forgejo.DeployKey('pathweb-private-gitops-key', {
        repositoryId: privateGitopsRepo.id,
        key: deployKey.publicKeyOpenssh,
        readOnly: true,
        title: 'Pathweb FluxCD GitOps Deploy Key'
    }, { parent: deployKey, deleteBeforeReplace: true, ignoreChanges: ['*'] })
]

// Load the FluxInstance CRD. Cluster management from this point on is handled by FluxCD.
const fluxInstance = new k8s.yaml.ConfigFile('pathweb-flux-instance', {
    file: '../clusters/pathweb/flux-instance.yaml',
    skipAwait: true
}, { dependsOn: [fluxOperator, ...deployKeys, k8sSecret], deletedWith: fluxOperator })
