import * as pulumi from '@pulumi/pulumi';
import * as schematics from '../talos-schematics';
import { Config } from '@pulumi/pulumi';

const pathwebConfig = new Config('talos-pathweb')
const homelab = new Config('homelab')

const talosVersion = pathwebConfig.require('talos-version')
const k8sVersion = pathwebConfig.require('kubernetes-version')
const defaultFactoryRegistry = "factory.talos.dev"

const harborRegistry = homelab.get('harbor-registry')
const imageFactoryCacheProject = (homelab.getObject<{[registry: string]: string}>('harbor-caches') ?? {})[defaultFactoryRegistry]

export const factoryImageRegistry = (harborRegistry && imageFactoryCacheProject) ? `${harborRegistry}/${imageFactoryCacheProject}` : defaultFactoryRegistry

const schematicsOutput = pulumi.all([
    schematics.nocloud.qemu.default.id,
    schematics.nocloud.qemu.amdgpu.id,
    schematics.nocloud.qemu.i915.id,
    schematics.nocloud.qemu.nvidia.id,
    schematics.metal.rpi.id
]).apply( ([qemu, qemuAmdgpu, qemuI915, qemuNvidia, rpi]) => ({
    "nocloud-qemu": qemu,
    "nocloud-qemu-amdgpu": qemuAmdgpu,
    "nocloud-qemu-i915": qemuI915,
    "nocloud-qemu-nvidia": qemuNvidia,
    "metal-rpi": rpi
}))

export const versionData = schematicsOutput.apply(schematics => ({
    version: talosVersion,
    "k8s_version": k8sVersion,
    "default_type": "proxmox", // Legacy from powershell scripts?
    "factory_image_registry": factoryImageRegistry,
    schematics,
    "image_override": {}
}))
