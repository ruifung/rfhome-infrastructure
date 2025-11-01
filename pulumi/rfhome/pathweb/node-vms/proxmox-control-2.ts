import * as proxmoxve from '@muhlba91/pulumi-proxmoxve';
import * as pulumi from '@pulumi/pulumi';
import { pveVoyager } from '../../proxmox-ve';
import { pveTalosIsos } from '../talos-boot-assets';
import { pathwebClusterParent } from '../talos-machineconfig';
import * as nodes from '../talos-nodes';
import { prepareNodeCloudInit } from './pve-helper';


const node = nodes.control2
const cloudInitData = prepareNodeCloudInit(node, pathwebClusterParent)

export const pathwebControl2VM = new proxmoxve.vm.VirtualMachine("pathweb-control-2", {
    name: node.hostname,
    machine: "q35",
    bios: "ovmf",
    nodeName: "voyager2",
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
        ssd: true,
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
        { bridge: "servers", macAddress: "BC:24:11:9F:0E:CF" }
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
    protect: false,
});
