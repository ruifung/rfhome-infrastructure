import * as talos from '@pulumiverse/talos'
import * as pve from '@muhlba91/pulumi-proxmoxve'
import * as pulumi from '@pulumi/pulumi'
import { nocloud } from '../talos-schematics'
import { pveBaldric } from '../proxmox-ve'
import { Schematic } from '@pulumiverse/talos/imagefactory'


const pathwebConfig = new pulumi.Config('talos-pathweb')
const homelabConfig = new pulumi.Config('homelab')

const talosVersion = pathwebConfig.require('talos-version')
const pveS3datastore = homelabConfig.require('pve-s3-datastore-id')

function downloadSchematicIsoToSharedStorage(key: string, schematic: Schematic) {
    const urls = talos.imagefactory.getUrlsOutput({
        talosVersion: talosVersion.substring(1),
        schematicId: schematic.id,
        architecture: 'amd64',
        platform: 'nocloud'
    })
    const downloadedFile = new pve.download.File(`talos-iso-amd64-nocloud-${key}`, {
        datastoreId: pveS3datastore,
        contentType: 'iso',
        nodeName: 'baldric',
        url: urls.urls.iso,
        fileName: pulumi.interpolate`talos-${talosVersion}-${key}-${schematic.id}.iso`
    }, {provider: pveBaldric, dependsOn: [schematic]})
    return downloadedFile
}


export const pveTalosIsos = {
    default: downloadSchematicIsoToSharedStorage('default', nocloud.qemu.default),
}
