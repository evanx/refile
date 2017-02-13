
# R8

This service archives JSON documents from Redis to disk-based BLOB storage.

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
        snapshotId: {
            description: 'the snapshot ID for recovery',
            default: 1
        },
        outq: {
            description: 'the output queue for processed keys',
            default: 'none'
        }
    }
}
```

## Usage

The application sets some JSON data in Redis:
```sh
redis-cli set user:evanxsummers '{"twitter": "@evanxsummers"}'
```
The application pushes the updated key to `r8:q`
```sh
redis-cli lpush r8:q user:evanxsummers
```

This utility will read the JSON content from Redis and write it to BLOB storage, where it is retrievable via HTTP.

A document that has been deleted can similarly be pushed to this queue:
```sh
redis-cli del user:evanxsummers
redis-cli lpush r8:q user:evanxsummers
```
where in this case, R8 will remove the JSON file from the BLOB store.

### Files

In the case of the key `user:evanxsummers` the following files are written to storage:
```
data/key/user/evanxs/ummers/user_evanxsummers.json
data/sha/feEfRF/o51vn0/5Dllex/z6eIQR/feEfRFo51vn05Dllexz6eIQR4f4.user_evanxsummers.json.gz
data/time/2017-01-29/18h12m07/546/user_evanxsummers.json.gz
```
where the file in `data/key/` is the current version of the document to be published via HTTP.

Note that the path is split up with `/` so that when using a simple file system as BLOB storage, there will be a limited number of files in each subdirectory, for practical reasons.

Additionally two (compressed) historical versions are stored:
- a copy named according to the SHA of the contents i.e. content addressable
- a copy named for the timestamp when the content is archived

These gzipped files are intended to be unique and immutable, i.e. not overwritten by subsequent updates. The SHA files are intended for versioning, and the timestamped copies are useful for debugging.

```sh
$ zcat data/time/2017-01-29/18h12m07/546/user_evanxsummers.json.gz | jq '.'
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

https://twitter.com/@evanxsummers
