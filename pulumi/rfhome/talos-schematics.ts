import { imagefactory } from '@pulumiverse/talos'

const commonKernelArgs = [
    "net.ifnames=0"
]

const commonOfficialExtensions = [
    "siderolabs/binfmt-misc",
    "siderolabs/ctr",
    "siderolabs/fuse3",
    "siderolabs/gvisor",
    "siderolabs/iscsi-tools",
    "siderolabs/kata-containers",
    "siderolabs/nvme-cli",
    "siderolabs/youki"
]

const noclodQemuSchematic = new imagefactory.Schematic('nocloud-qemu', {
    schematic: JSON.stringify({
        customization: {
            extraKernelArgs: [
                ...commonKernelArgs
            ],
            systemExtensions: {
                officialExtensions: [
                    ...commonOfficialExtensions,
                    "siderolabs/qemu-guest-agent",
                ]
            }
        }
    })
}, {replaceOnChanges: ['schematic']})

const nocloudQemuAmdGpuSchematic = new imagefactory.Schematic('nocloud-qemu-amdgpu', {
    schematic: JSON.stringify({
        customization: {
            extraKernelArgs: [
                ...commonKernelArgs
            ],
            systemExtensions: {
                officialExtensions: [
                    ...commonOfficialExtensions,
                    "siderolabs/qemu-guest-agent",
                    "siderolabs/amdgpu"
                ]
            }
        }
    })
}, {replaceOnChanges: ['schematic']})

const nocloudQemuI915GpuSchematic = new imagefactory.Schematic('nocloud-qemu-i915', {
    schematic: JSON.stringify({
        customization: {
            extraKernelArgs: [
                ...commonKernelArgs
            ],
            systemExtensions: {
                officialExtensions: [
                    ...commonOfficialExtensions,
                    "siderolabs/qemu-guest-agent",
                    "siderolabs/i915"
                ]
            }
        }
    })
}, {replaceOnChanges: ['schematic']})

const nocloudQemuNvidiaGpuSchematic = new imagefactory.Schematic('nocloud-qemu-nvidia', {
    schematic: JSON.stringify({
        customization: {
            extraKernelArgs: [
                ...commonKernelArgs
            ],
            systemExtensions: {
                officialExtensions: [
                    ...commonOfficialExtensions,
                    "siderolabs/qemu-guest-agent",
                    "siderolabs/nvidia-container-toolkit-production",
                    "siderolabs/nvidia-open-gpu-kernel-modules-production"
                ]
            }
        }
    })
}, {replaceOnChanges: ['schematic']})

const metalRpiSchematic = new imagefactory.Schematic('metal-rpi', {
    schematic: JSON.stringify({
        overlay: {
            image: "siderolabs/sbc-raspberrypi",
            name: "rpi_generic"
        },
        customization: {
            extraKernelArgs: [
                ...commonKernelArgs
            ],
            systemExtensions: {
                officialExtensions: [
                    ...commonOfficialExtensions,
                    "siderolabs/vc4"
                ]
            }
        }
    })
}, {replaceOnChanges: ['schematic']})

export const nocloud = {
    qemu: {
        default: noclodQemuSchematic,
        amdgpu: nocloudQemuAmdGpuSchematic,
        i915: nocloudQemuI915GpuSchematic,
        nvidia: nocloudQemuNvidiaGpuSchematic
    }
}
export const metal = {
    rpi: metalRpiSchematic
}
