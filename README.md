
# r8

This service archives JSON documents from Redis to disk-based BLOB storage.

<img src="https://raw.githubusercontent.com/evanx/r8/master/docs/readme/main2.png"/>

## Use case

The intended use case is for publishing cacheable data to the web. Structured data is stored in Redis for simplicity and in-memory speed. However, to reduce RAM requirements, "large" JSON documents/collections are archived to disk-based storage. Those documents are typically retrieved via HTTP e.g. via Nginx.

## Config

See `lib/config.js`
```javascript
module.exports = {
    description: 'Utility to archive Redis JSON keys to BLOB storage.',
    required: {
        blobStore: {
            description: 'the BLOB store options e.g. directory for file storage',
            default: 'r8data/'
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
        snapshotId: {
            description: 'the snapshot ID for recovery',
            default: 1
        },
        outq: {
            description: 'the output queue for archived keys',
            required: false
        },
        expire: {
            description: 'the expiry to set on archived keys',
            unit: 'seconds',
            example: 60,
            required: false
        },
    }
}
```
where archived keys are pushed to `outq` or set to `expire` otherwise they are deleted.

That is to say, if `outq` is set, then further processing thereby might expire or delete the archived keys.

## Usage

The application sets some JSON data in Redis:
```sh
redis-cli set user:evanxsummers '{"twitter": "@evanxsummers"}'
```
The application pushes the updated key to `r8:q`
```sh
redis-cli lpush r8:q user:evanxsummers
```

This utility will read the JSON content from Redis and write it to BLOB storage.

The intention is that these documents are retrieved via HTTP sourced from that BLOB storage, rather than from Redis.

A document that has been deleted can similarly be pushed to this queue:
```sh
redis-cli del user:evanxsummers
redis-cli lpush r8:q user:evanxsummers
```
where in this case, r8 will remove the JSON file from the BLOB store.

### Files

In the case of the key `user:evanxsummers` the following files are written to storage:
```
data/key/SY4/JOk/user-evanxsummers.json
data/sha/gUi/NpQ/gUiWKhI8O2Kai3jXAFKhTXFWNpQ.user-evanxsummers.json.gz
data/time/2017-02-14/01h12m20/998/user-evanxsummers.json.gz
```
where the file in `data/key/` is the current version of the document to be published via HTTP.

Note that the path is split up with `/` so that when using a simple file system as BLOB storage, there will be a limited number of files in each subdirectory, for practical reasons. In the case of `/data/key` the path prefixes are determined from the SHA of the key itself.

Additionally two (compressed) historical versions are stored:
- a copy named according to the SHA of the contents i.e. content addressable
- a copy named for the timestamp when the content is archived

These gzipped files are intended to be unique and immutable, i.e. not overwritten by subsequent updates. The SHA files are intended for versioning, and the timestamped copies are useful for debugging.

```sh
$ zcat r8data/time/2017-02-14/01h12m20/998/user-evanxsummers.json.gz | jq '.'
{
  "twitter": "@evanxsummers"
}
```

The SHA and timestamp for each archival is recorded in Redis against the current snapshot ID. That data in Redis, together with the above files, should be sufficient to enable another service to create a snapshot, e.g. for recovery.

Another service might serve a specific snapshot from the BLOB store, by looking up the corresponding SHA (version) from Redis for that document and snapshot. Such a service can be useful for a rollback/forward strategy.

Incidently, the compressed content can be streamed as is in `gzip` by the HTTP server, assuming the client accepts `gzip` encoding.

The following related services are planned:
- delete an older snapshot, including related SHA files
- extract a specific snapshot to BLOB storage
- redirecting web server for a specific snapshot i.e. to the appropriate SHA file
- proxying web server for a specific snapshot

## Docker

You can build as follows:
```
docker build -t r8 https://github.com/evanx/r8.git
```

See `test/demo.sh` https://github.com/evanx/r8/blob/master/test/demo.sh
- isolated network `test-r8-network`
- isolated Redis instance named `test-r8-redis`
- two `spiped` containers to test encrypt/decrypt tunnels
- the prebuilt image `evanxsummers/r8`
- host volume `$HOME/volumes/test-r8/data`


## Implementation

See `lib/index.js`

We monitor the `r8:q` input queue.
```javascript
    const blobStore = require(config.blobStoreType)(config.blobStore);
    while (true) {
        const key = await client.brpoplpushAsync('r8:q', 'r8:busy:q', 1);    
        ...        
    }
```

We record the following in Redis:
```javascript
multi.hset(`r8:sha:h`, key, sha);
multi.zadd(`r8:key:${key}:z`, timestamp, sha);
multi.hset(`r8:${config.snapshotId}:sha:h`, key, sha);
multi.srem(`r8:${config.snapshotId}:rem:s`, key);
```            
where the `sha` of the `key` is stored for the snapshot, and also the historical SHA's for a specific key are recorded in a sorted set by the `timestamp`

If the specified Redis key does not exist, we can assume it was deleted. In this case we record the following in Redis:
```javascript
multi.hdel(`r8:sha:h`, key);
multi.zadd(`r8:key:${key}:rem:z`, timestamp, sha);
multi.hdel(`r8:${config.snapshotId}:sha:h`, key);
multi.sadd(`r8:${config.snapshotId}:rem:s`, key);
```
where we delete current entries for this key and add it to `rem:s` for the snapshot, for recovery of its deleted status for the current snapshot.

<hr>
https://twitter.com/@evanxsummers
