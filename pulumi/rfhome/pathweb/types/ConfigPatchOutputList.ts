import { Output, UnwrappedArray } from '@pulumi/pulumi';
import { ConfigPatch } from './ConfigPatch';

export type ConfigPatchOutputList = Output<UnwrappedArray<Output<ConfigPatch>>>;
