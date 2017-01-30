
# R8

Redis-managed JSON document archiver for simple web-scale publishing.

This service archives JSON documents from Redis to disk-based BLOB storage.

That collection of JSON documents can be published via HTTP e.g. via CloudFlare CDN using Nginx, or what have you.

## Use case

Data required to lookup, query and aggregate our data would be stored in Redis for simplicity and in-memory speed. To reduce RAM requirements, "large" JSON documents/collections are archived to disk-based storage. Those documents are fetched via HTTP. This facilitates caching. As such the intended use case is for data that is cacheable, e.g. for some number of seconds or minutes.

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
redis-cli set evanxsummers '{"twitter": "@evanxsummers"}'
```
The application pushes the updated key to `r8:q`
```sh
redis-cli lpush r8:q evanxsummers
```

This utility will read the JSON content from Redis and write it to BLOB storage e.g. the file system.
The JSON content can then be served via static web server e.g. Nginx, via CDN, or what have you.

A document that has been deleted can similarly be pushed to this queue:
```sh
redis-cli del evanxsummers
redis-cli lpush r8:q evanxsummers
```
where in this case, R8 will remove the JSON file from the BLOB store.

### Files

For example, the following files are written to storage:
```
data/key/evanxs/ummers/evanxsummers.json
data/sha/feEfRF/o51vn0/5Dllex/z6eIQR/feEfRFo51vn05Dllexz6eIQR4f4.evanxsummers.json.gz
data/time/2017-01-29/18h12m07/evanxsummers.json.gz
```
where the first file in `data/key/` is the current version of the document to be published.

Note that the path is split up with `/` so that when using a simple file system as BLOB storage, there will be a limited number of files in each subdirectory, for practical reasons.

Additionally two (compressed) historical versions are stored:
- a copy named according to the SHA of the contents i.e. content addressable
- a copy named for the timestamp when the content is archived

With the exception of the "current" (uncompressed) version, these names are intended to be unique and the files immutable, i.e. not overwritten by subsequent updates. As such these historical versions can be inspected and recovered.

```sh
$ zcat data/time/2017-01-29/18h12m07/evanxsummers.json.gz | jq '.'
{
  "twitter": "@evanxsummers"
}
```

Incidently, the timestamp is the archive time. Subsequent updates in the same second might overwrite the timestamped copy. Alternatively the service might reschedule the archival for a subsequent time. However this solution is intended for cacheable content that is published to the web, that is not typically updated multiple times per second.

The SHA and timestamp for each archival is recorded in Redis against the current snapshot ID. That data in Redis, together with the above files, should be sufficient to enable another service to create a snapshot, e.g. for recovery. Also, another service is required to prune the BLOB store, e.g. remove files from an older snapshot that is no longer required.

Another service might serve a specific snapshot from the BLOB store, by looking up the corresponding SHA (version) from Redis for that document and snapshot.

Incidently, the compressed content can be streamed as is in `gzip` by the HTTP server, assuming the client accepts `gzip` encoding.


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
    multi.zadd(`r8:key:${key}:z`, timestamp, sha);
    multi.hset(`r8:sha:h`, key, sha);
    multi.hset(`r8:${config.snapshotId}:sha:h`, key, sha);
    multi.srem(`r8:${config.snapshotId}:rem:s`, key);
    multi.lrem('r8:busy:q', 1, key);
    if (config.outq) {
        multi.lpush(config.outq, key);
    } else {
        multi.del(key);            
    }
```            
where the `sha` of the `key` is stored for the snapshot, and also the historical SHA's for a specific key are recorded in a sorted set by the `timestamp.`

If the specified Redis key does not exist, we can assume it was deleted. In this case we record the following in Redis:
```javascript
    multi.hdel(`r8:sha:h`, key);
    multi.hdel(`r8:${config.snapshotId}:sha:h`, key);
    multi.sadd(`r8:${config.snapshotId}:rem:s`, key);
    multi.lrem('r8:busy:q', 1, key);
    if (config.outq) {
        multi.lpush(config.outq, key);
    }
```
where we delete current entries for this key and add it to `rem:s` for the snapshot, for recovery of its deleted status for the current snapshot.


https://twitter.com/@evanxsummers
