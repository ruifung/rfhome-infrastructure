import * as aws from '@pulumi/aws'
import { Config } from '@pulumi/pulumi'

const homelabConfig = new Config('homelab')

export const localS3Provider = new aws.Provider('local-s3-versitygw', {
    accessKey: homelabConfig.require('local-s3-access-key'),
    secretKey: homelabConfig.require('local-s3-secret-key'),
    endpoints: [
        {s3: homelabConfig.require('local-s3-endpoint')}
    ],
    region: 'us-east-1',
    s3UsePathStyle: false,
    skipRegionValidation: true,
    skipCredentialsValidation: true,
    skipMetadataApiCheck: true,
    skipRequestingAccountId: true
})
