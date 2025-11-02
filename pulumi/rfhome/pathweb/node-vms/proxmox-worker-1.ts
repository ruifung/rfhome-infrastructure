import * as proxmoxve from '@muhlba91/pulumi-proxmoxve';
import * as pulumi from '@pulumi/pulumi';
import { pveVoyager } from '../../proxmox-ve';
import { pveTalosIsos } from '../talos-boot-assets';
import { pathwebClusterParent } from '../talos-machineconfig';
import * as nodes from '../talos-nodes';
import { prepareNodeCloudInit } from './pve-helper';

const node = nodes.worker1
const cloudInitData = prepareNodeCloudInit(node, pathwebClusterParent)

export const pathwebWorker1VM = new proxmoxve.vm.VirtualMachine("pathweb-worker-1", {
    name: node.hostname,
    machine: "q35",
    bios: "ovmf",
    nodeName: "voyager1",
    started: true,
    cpu: {
        cores: 3,
        flags: [],
        type: "host",
        units: 200,
    },
    memory: {
        dedicated: 10240,
        floating: 10240,
    },
    disks: [{
        datastoreId: "pve-images",
        discard: "on",
        "interface": "scsi0",
        iothread: true,
        size: 100,
        ssd: true,
        replicate: false,
        backup: false
    }],
    efiDisk: {
        datastoreId: "pve-images",
        preEnrolledKeys: false,
        type: "4m",
    },
    cdrom: {
        fileId: pulumi.interpolate`${pveTalosIsos.default.datastoreId}:iso/${pveTalosIsos.default.fileName}`,
        interface: 'ide2'
    },
    initialization: {
        datastoreId: 'pve-images',
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
        { bridge: "servers", macAddress: "BC:24:11:54:FE:E6", queues: 3},
        { bridge: "iot", macAddress: "BC:24:11:43:77:27", queues: 3},
        { bridge: "storage", macAddress: "BC:24:11:99:FD:5E", queues: 3, mtu: 1, firewall: true},
    ],
    operatingSystem: {
        type: "l26",
    },
    scsiHardware: "virtio-scsi-single",
    onBoot: true,
    startup: {
        order: 3,
    },
    tags: [
        "pulumi-managed",
        "kubernetes",
        "linux",
        "pathweb",
        "talos",
    ],
    usbs: [
        {mapping: 'sonoff-zb3'}
    ],
    vga: {type: 'virtio-gl'},
    serialDevices: [],
    reboot: false,
    rebootAfterUpdate: false,
    poolId: 'rfhome-network-essential',

}, {
    parent: pathwebClusterParent,
    provider: pveVoyager,
    protect: false,
    ignoreChanges: ['disks[0].speed']
});
