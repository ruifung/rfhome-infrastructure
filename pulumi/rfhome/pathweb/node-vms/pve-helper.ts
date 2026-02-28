import * as aws from '@pulumi/aws';
import * as pulumi from '@pulumi/pulumi';
import { localS3Provider } from '../../local-s3';
import { generateMachineConfiguration } from '../talos-machineconfig';
import { NodeDefinition } from '../types/NodeDefinition';


const homelabConfig = new pulumi.Config('homelab')
const pveBucket = homelabConfig.require('pve-s3-bucket')

export function prepareNodeCloudInit(node: NodeDefinition, parent: pulumi.Resource | undefined = undefined) {
    const userDataFile = new aws.s3.BucketObject(`${node.hostname}_cloudinit_userdata`, {
        bucket: pveBucket,
        key: pulumi.interpolate`snippets/cloud-init_${node.hostname}_user-data`,
        content: generateMachineConfiguration(node).machineConfiguration,
        contentType: 'application/yaml',
        acl: 'private',
    }, { provider: localS3Provider, parent, ignoreChanges: ['contentEncoding', 'versionId'] })

    return pulumi.interpolate`${userDataFile.bucket}:${userDataFile.key}`
}
