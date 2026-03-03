import * as pulumi from '@pulumi/pulumi'
import { NodeDefinition } from './NodeDefinition';

// This is the shape of a legacy config patch, which is just a partial TalosConfig that will be merged into the generated config for a node.
export type ConfigPatch =  (object | { [key: string]: any; }) & { length?: never; };
// This is the newer shape of a config patch, which resembles a Kubernetes resource, and is used with talos newer multi-document config format.
// It must have an apiVersion and kind field, and can have any other fields as well (depending on the kind of resource it represents).
export type TypedConfigPatch = {apiVersion: string, kind: string} & ConfigPatch;
export type ConfigPatchOutput = pulumi.Output<ConfigPatch>;
export type TypedConfigPatchOutput = pulumi.Output<TypedConfigPatch>;

// All patches should be provided by a function that matches this type.
// The function takes a NodeDefinition as input, and returns an array of either ConfigPatch or ConfigPatchOutput.
// This allows multi-doc config patches to be generated dynamically based on the node definition.
export type ConfigPatchProvider = (node: NodeDefinition) => (ConfigPatchOutput|ConfigPatch)[];
export type TypedConfigPatchProvider = (node: NodeDefinition) => (TypedConfigPatchOutput|TypedConfigPatch)[];

export function v1alpha1Config(kind: string, patch: ConfigPatch): TypedConfigPatch {
    return {
        apiVersion: 'v1alpha1',
        kind,
        ...patch
    }
}
