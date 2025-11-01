import * as pulumi from '@pulumi/pulumi'
import * as pve from '@muhlba91/pulumi-proxmoxve'


const homelabConfig = new pulumi.Config('homelab')
export const pveVoyager = new pve.Provider('pve-voyager', {
    apiToken: homelabConfig.require('pve-voyager-token'),
    endpoint: homelabConfig.require('pve-voyager-endpoint'),
})

export const pveBaldric = new pve.Provider('pve-baldric', {
    apiToken: homelabConfig.require('pve-baldric-token'),
    endpoint: homelabConfig.require('pve-baldric-endpoint'),
})
