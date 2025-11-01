import * as proxmoxve from '@muhlba91/pulumi-proxmoxve';
import * as pulumi from '@pulumi/pulumi';
import { pveBaldric } from '../../proxmox-ve';
import { pveTalosIsos } from '../talos-boot-assets';
import { pathwebClusterParent } from '../talos-machineconfig';
import * as nodes from '../talos-nodes';
import { prepareNodeCloudInit } from './pve-helper';



const node = nodes.control3
const cloudInitData = prepareNodeCloudInit(node, pathwebClusterParent)

export const pathwebControl3VM = new proxmoxve.vm.VirtualMachine("pathweb-control-3", {
    name: node.hostname,
    vmId: 103,
    machine: "q35",
    bios: "ovmf",
    nodeName: "baldric",
    started: true,
    cpu: {
        cores: 4,
        flags: [],
        type: "host",
        units: 2000,
    },
    memory: {
        dedicated: 6144,
        floating: 6144,
    },
    disks: [{
        datastoreId: "local-zfs",
        discard: "on",
        "interface": "scsi0",
        iothread: true,
        size: 32,
        ssd: true,
    }],
    efiDisk: {
        datastoreId: "local-zfs",
        preEnrolledKeys: false,
        type: "4m",
    },
    cdrom: {
        fileId: pulumi.interpolate`${pveTalosIsos.default.datastoreId}:iso/${pveTalosIsos.default.fileName}`,
        interface: 'ide2'
    },
    initialization: {
        datastoreId: 'local-zfs',
        interface: 'ide0',
        userDataFileId: cloudInitData,
        ipConfigs: [
            {
                ipv4: { address: 'dhcp' },
                ipv6: { address: 'auto' }
            }
        ],
        type: 'nocloud'
    },
    agent: { enabled: true },
    networkDevices: [
        { bridge: "servers", macAddress: "BC:24:11:88:5D:E3" }
    ],
    operatingSystem: {
        type: "l26",
    },
    scsiHardware: "virtio-scsi-single",
    startup: {
        downDelay: 0,
        order: 1,
        upDelay: 0,
    },
    tags: [
        "pulumi-managed",
        "kubernetes",
        "linux",
        "pathweb",
        "talos",
    ],
    usbs: [],
    serialDevices: [],
    reboot: false,
    rebootAfterUpdate: false,
    poolId: 'rfhome-network-essential',
}, {
    parent: pathwebClusterParent,
    provider: pveBaldric,
    protect: false,
});
