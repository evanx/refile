module.exports = {
    description: 'Utility to archive Redis JSON keys to BLOB storage.',
    required: {
        blobStore: {
            description: 'the BLOB store options e.g. directory for file storage',
            default: 'data/'
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
        snapshot: {
            description: 'the snapshot ID for recovery',
            default: 1
        },
        outq: {
            description: 'the output queue for processed keys',
            required: false
        },
        expire: {
            description: 'the expiry to set on archived keys',
            unit: 'seconds',
            example: 60,
            required: false
        },
        action: {
            description: 'the action to perform on archived keys if expire not set',
            options: ['delete'],
            required: false
        },
        mode: {
            description: 'the mode of operation',
            note: 'not implemented yet',
            default: 'snapshot',
            options: ['minimal'],
            hint: 'Minimal mode does not save snapshot'
        },
        namespace: {
            description: 'the Redis namespace for this service',
            default: 'reo'
        },
        loggerLevel: {
            description: 'the logging level',
            default: 'info',
            example: 'debug'
        }

    },
    development: {
        loggerLevel: 'debug',
        exit: 'empty',
    },
    test: {
        loggerLevel: 'debug'
    }
}
