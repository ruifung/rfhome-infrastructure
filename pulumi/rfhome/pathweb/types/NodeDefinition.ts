import { Schematic } from '@pulumiverse/talos/imagefactory';

export interface VMSpec {
    cpu: number
}
export interface NodeDefinition {
    address: string;
    hostname: string;
    role: 'controlplane' | 'worker';
    labels?: { [label: string]: string; };
    schematic: Schematic;

    vmSpec?: VMSpec;
}
