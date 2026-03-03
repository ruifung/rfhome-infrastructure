import { ConfigPatch, ConfigPatchProvider } from "../types/ConfigPatch";
import * as local from "@pulumi/local"
import * as yaml from 'js-yaml'


// Read the cluster DNS IPs from the CoreDNS configuration
const coreDnsValues = local.getFileOutput({
    filename: 'rfhome/pathweb/coredns-values.yaml'
}).apply(file => yaml.load(file.content) as any)

export const coreDnsConfigPatch: ConfigPatchProvider = () => [{
    machine: {
        kubelet: {
            clusterDNS: coreDnsValues.apply(values => values.service.clusterIPs)
        }
    }
}]
