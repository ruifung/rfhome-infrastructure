import { imagefactory } from '@pulumiverse/talos'

const commonKernelArgs = [
    "net.ifnames=0"
]

const commonOfficialExtensions = [
    "siderolabs/binfmt-misc",
    "sidreolabs/ctr",
    "sidreolabs/fuse3",
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
                    "siderolabs/qemu-quest-agent",
                ]
            }
        }
    })
})

const nocloudQemuAmdGpuSchematic = new imagefactory.Schematic('nocloud-qemu-amdgpu', {
    schematic: JSON.stringify({
        customization: {
            extraKernelArgs: [
                ...commonKernelArgs
            ],
            systemExtensions: {
                officialExtensions: [
                    ...commonOfficialExtensions,
                    "siderolabs/qemu-quest-agent",
                    "siderolabs/amdgpu"
                ]
            }
        }
    })
})

const nocloudQemuI915GpuSchematic = new imagefactory.Schematic('nocloud-qemu-i915', {
    schematic: JSON.stringify({
        customization: {
            extraKernelArgs: [
                ...commonKernelArgs
            ],
            systemExtensions: {
                officialExtensions: [
                    ...commonOfficialExtensions,
                    "siderolabs/qemu-quest-agent",
                    "siderolabs/i915"
                ]
            }
        }
    })
})

const nocloudQemuNvidiaGpuSchematic = new imagefactory.Schematic('nocloud-qemu-nvidia', {
    schematic: JSON.stringify({
        customization: {
            extraKernelArgs: [
                ...commonKernelArgs
            ],
            systemExtensions: {
                officialExtensions: [
                    ...commonOfficialExtensions,
                    "siderolabs/qemu-quest-agent",
                    "siderolabs/nvidia-container-toolkit-production",
                    "siderolabs/nvidia-open-gpu-kernel-modules-production"
                ]
            }
        }
    })
})

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
})

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
