// apiVersion: v1alpha1
// kind: OOMConfig
// triggerExpression: "false"
// cgroupRankingExpression: "0.0"
// sampleInterval: "5s"

import { TypedConfigPatchProvider, v1alpha1Config } from '../types/ConfigPatch';

export const userspaceOomPatch: TypedConfigPatchProvider = () => [
    v1alpha1Config('OOMConfig', {
        triggerExpression: 'false',
        cgroupRankingExpression: '0.0',
        sampleInterval: '5s'
    })
]
