import * as proxmoxve from '@muhlba91/pulumi-proxmoxve';
import * as pulumi from '@pulumi/pulumi';
import { pveVoyager } from '../../proxmox-ve';
import { pveTalosIsos } from '../talos-boot-assets';
import { pathwebClusterParent } from '../talos-machineconfig';
import * as nodes from '../talos-nodes';
import { prepareNodeCloudInit } from './pve-helper';
import { pathwebControl2VM } from './proxmox-control-2';


const node = nodes.control1
const cloudInitData = prepareNodeCloudInit(node, pathwebClusterParent)

export const pathwebControl1VM = new proxmoxve.vm.VirtualMachine("pathweb-control-1", {
    name: node.hostname,
    machine: "q35",
    bios: "ovmf",
    nodeName: "voyager1",
    started: true,
    cpu: {
        cores: 2,
        flags: [],
        type: "host",
        units: 2000,
    },
    memory: {
        dedicated: 6144,
        floating: 6144,
    },
    disks: [{
        datastoreId: "local",
        discard: "on",
        "interface": "scsi0",
        iothread: true,
        size: 32,
        ssd: true
    }],
    efiDisk: {
        datastoreId: "local",
        preEnrolledKeys: false,
        type: "4m",
    },
    cdrom: {
        fileId: pulumi.interpolate`${pveTalosIsos.default.datastoreId}:iso/${pveTalosIsos.default.fileName}`,
        interface: 'ide2'
    },
    initialization: {
        datastoreId: 'local',
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
        { bridge: "servers", macAddress: "BC:24:11:37:F1:E5" }
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
    provider: pveVoyager,
    protect: true,
    ignoreChanges: ['disks[0].speed'],
    dependsOn: [pathwebControl2VM]
});
