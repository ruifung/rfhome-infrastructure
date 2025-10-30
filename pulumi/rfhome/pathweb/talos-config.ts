import * as local from '@pulumi/local';
import * as pulumi from '@pulumi/pulumi';
import { machine } from '@pulumiverse/talos';
import * as yaml from 'js-yaml';
import { getNodePatches } from './config-patches/talos-patches';
import { clusterNodes } from './talos-nodes';
import { NodeDefinition } from './types/NodeDefinition';
import { ComponentResource } from '@pulumi/pulumi'
import { versionData } from './talos-version';


const pathwebConfig = new pulumi.Config('talos-pathweb')
const homelabConfig = new pulumi.Config('homelab')


export const pathwebClusterParent = new ComponentResource('anchor:talos-cluster', 'pathweb')

const secrets = new machine.Secrets("pathweb-secrets", {talosVersion: "v1.3"}, {parent: pathwebClusterParent, protect: true})

function generateMachineConfiguration(node: NodeDefinition): pulumi.Output<machine.GetConfigurationResult> {
    return machine.getConfigurationOutput({
        machineSecrets: secrets.machineSecrets,
        clusterName: pathwebConfig.require('cluster-name'),
        clusterEndpoint: pathwebConfig.require('cluster-endpoint'),
        machineType: node.role,
        talosVersion: pathwebConfig.require('talos-version'),
        kubernetesVersion: pathwebConfig.require('kubernetes-version'),
        docs: false,
        examples: false,
        configPatches: pulumi.all(getNodePatches(node))
            .apply(patches => patches.map( it => yaml.dump(it)))
    })
}

const serverDomain = homelabConfig.require('servers-domain')
// Write the config files where the legacy powershell scripts expect them.
for (const node of clusterNodes) {
    const config = generateMachineConfiguration(node)
    const configFile = new local.File(`talos-node-config_${node.hostname}`, {
        filename: `../talos/pathweb/machineconfig/${node.hostname}.${serverDomain}.yaml`,
        content: config.machineConfiguration
    }, {parent: pathwebClusterParent})
}

// Generate the version file used by the legacy powershell scripts
new local.File("talos-version-file", {
    content: versionData.apply(data => JSON.stringify(data, null, 2)),
    filename: '../talos/pathweb/talos-version.json'
}, {parent: pathwebClusterParent})

// Code for debugging patch failures
// for (const [idx, patch] of getNodePatches(control1).entries()) {
//     const tempFile = new local.File(`patch-testing-temp-file_${idx}`, {
//         filename: `temp/patch_temp_file_${idx}.yml`,
//         content: pulumi.output(patch).apply(yaml.dump)
//     })
// }
