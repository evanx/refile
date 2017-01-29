
# R8

Redis-managed content archiver, suitable for web-scale publishing of slowly changing JSON data, in a simple and robust fashion.

This service archives JSON documents to BLOB storage. From said storage, that collection of JSON documents can be published via HTTP e.g. via CloudFlare CDN using Nginx.

Information required to lookup, query and aggregate data would be stored in Redis for simplicity and in-memory speed. However "large" JSON documents are archived to disk-based storage and fetched via HTTP. They are deleted from Redis, to minimise unnecessary RAM usage.

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
data/key/evan/xsum/mers/evanxsummers.json
data/sha/feEfRF/o51vn0/5Dllex/z_eIQR/feEfRFo51vn05Dllexz_eIQR4f4.evanxsummers.json.gz
data/time/2017-01-29/18h05m45/evanxsummers.json.gz
```

where the first file is the current version of the document.

Additionally two (compressed) historical versions are store:
- a copy named according to the SHA of the contents
- a copy name for the time that the content was modified

With the except of the "current" version, these documents are clearly unique and not overwritten by subsequent updates. As such historical versions can be inspected and recovered.

The SHA of a specific document is recorded against the current snapshot ID, and it's modtime. That data in Redis, together with the above files, should be sufficient to enable another service to create a snapshot, e.g. for recovery.

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
