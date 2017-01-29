
# R8

Redis-managed content archiver, suitable for web-scale publishing of slowly changing JSON data, in a simple and robust fashion.

This service archives JSON documents from Redis to BLOB storage, as per https://github.com/maxogden/abstract-blob-store

That collection of JSON documents can be published via HTTP e.g. via CloudFlare CDN using Nginx, or what have you.

Information required to lookup, query and aggregate data would be stored in Redis for simplicity and in-memory speed. However "large" JSON documents are archived to disk-based storage and fetched via HTTP. They are deleted from Redis, to minimise RAM requirements.

## Config

See `lib/config.js`
```javascript
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
    snapshotId: {
        description: 'the snapshot ID for recovery',
        default: 1
    },
    outq: {
        description: 'the output queue for processed keys',
        default: 'none'
    },
```

## Usage

The application pushes keys of JSON content that has been set in Redis:
```sh
echo '{"twitter": "@evanxsummers"}' | jq '.' | redis-cli -x set evanxsummers
redis-cli lpush r8:q evanxsummers
```

This utility will read the JSON content from Redis and write it to BLOB storage e.g. the file system.
The JSON content can then be served via static web server e.g. Nginx, via CDN, or what have you.

A document that has been deleted can similarly be pushed to this queue:
```sh
redis-cli del evanxsummers
redis-cli lpush r8:q evanxsummers
```
where in this case, R8 will remove the JSON file.

### Files

For example the following files are written to storage:
```
data/key/evanxs/ummers/evanxsummers.json
data/sha/feEfRF/o51vn0/5Dllex/z6eIQR/feEfRFo51vn05Dllexz6eIQR4f4.evanxsummers.json.gz
data/time/2017-01-29/18h12m07/evanxsummers.json.gz
```
where the first file in `data/key/` is the current version of the document.

Note that the path is split up with `/` so that when using a simple file system as BLOB storage, there will be a limited number of files in each subdirectory, for practical reasons.

Additionally two (compressed) historical versions are stored:
- a copy named according to the SHA of the contents
- a copy named for the time that the content was archived

With the exception of the "current" (uncompressed) version, these names are intended to be unique and the files immutable, i.e. not overwritten by subsequent updates. As such historical versions can be inspected and recovered.

```sh
$ zcat data/time/2017-01-29/18h12m07/evanxsummers.json.gz
{
  "twitter": "@evanxsummers"
}
```

Incidently, the timestamp is the archive time. Subsequent updates in the same second might overwrite the timestamped copy. Alternatively the service might reschedule the archival for a subsequent time. However this solution is intended for slowly changing content that is published to the web, benefits from CDN caching for many seconds or even minutes, and is not typically updated multiple times per second.

The SHA and timestamp for each archival is recorded in Redis against the current snapshot ID. That data in Redis, together with the above files, should be sufficient to enable another service to create a snapshot, e.g. for recovery. Clearly another service is required to prune the BLOB store, e.g. remove files from an older snapshot that is no longer required.

Another service will serve a specific snapshot from the same blob store, by looking up the corresponding SHA (version) from Redis for the requested document. Incidently, they can be streamed as is in `gzip` by the HTTP server, assuming the client accepts `gzip` encoding.


## Implementation

See `lib/index.js`

We monitor the `r8:q` input queue.
```javascript
const blobStore = require(config.blobStoreType)(config.blobStore);
while (true) {
    const key = await client.brpoplpushAsync('r8:q', 'r8:busy:q', 1);    
```

We record the following in Redis:
```javascript
    multi.zadd(`r8:key:${key}:z`, time, sha);
    multi.hset(`r8:sha:h`, key, sha);
    multi.hset(`r8:${config.snapshotId}:sha:h`, key, sha);
    multi.srem(`r8:${config.snapshotId}:rem:s`, key);
    multi.lrem('r8:busy:q', 1, key);
    if (config.outq) {
        multi.lpush(config.outq, key);
    } else {
        multi.del(key);            
```            

If the specified Redis keys does not exist, we can assume it was deleted. In this case we record the following in Redis:
```javascript
    multi.hdel(`r8:sha:h`, key);
    multi.hdel(`r8:${config.snapshotId}:sha:h`, key);
    multi.sadd(`r8:${config.snapshotId}:rem:s`, key);
    multi.lrem('r8:busy:q', 1, key);
    if (config.outq) {
        multi.lpush(config.outq, key);
```

https://twitter.com/@evanxsummers
