import * as local from '@pulumi/local'
import { Output } from '@pulumi/pulumi'
import { ConfigPatch, ConfigPatchProvider } from '../types/ConfigPatch'

export const containersSeccompPatch: ConfigPatchProvider = () => [local.getFileOutput({
    filename: 'rfhome/pathweb/config-patches/containers-seccomp.json'
}).apply(file => ({
    name: 'podman.json',
    value: JSON.parse(file.content)
})).apply(profile => ({
    machine: {
        seccompProfiles: [
            profile
        ]
    }
}))]
