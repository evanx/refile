module.exports = {
    description: 'Utility to archive Redis JSON keys to blob storage.',
    required: {
        blobStore: {
            description: 'the BLOB store options e.g. directory for file storage',
            default: 'tmp/data/'
        },
        blobStoreType: {
            description: 'the BLOB store type',
            default: 'fs-blob-store'
        },
        host: {
            description: 'the Redis host',
            default: 'localhost'
        },
        port: {
            description: 'the Redis port',
            default: 6379
        },
        namespace: {
            description: 'the Redis namespace for this service',
            default: 'r8'
        },
        snapshotId: {
            description: 'the snapshot ID for recovery',
            default: 1
        },
        outq: {
            description: 'the output queue for processed keys',
            default: 'none'
        },
        level: {
            description: 'the logging level',
            default: 'info',
            example: 'debug'
        }

    },
    development: {
        level: 'debug',
        exit: 'empty',
        snapshotId: 1
    }
}
