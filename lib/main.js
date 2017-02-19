
const assert = require('assert');
const crypto = require('crypto');
const zlib = require('zlib');
const lodash = require('lodash');
const Promise = require('bluebird');
const multiExecAsync = require('multi-exec-async');
const pathFormat = require('./pathFormat');

function removeAsync(store, key) {
    return new Promise((resolve, reject) => {
        store.remove({key},
            (err, result) => err ? reject(err) : resolve(result)
        );
    });
}

function writeAsync(store, key, data) {
    return new Promise((resolve, reject) => {
        const stream = store.createWriteStream({key},
            (err, result) => err ? reject(err) : resolve(result)
        );
        stream.write(data);
        stream.end();
    });
}

function gzipAsync(data) {
    return new Promise((resolve, reject) => {
        zlib.gzip(data,
            (err, result) => err ? reject(err) : resolve(result)
        );
    });
}

module.exports = async context => {
    const {config, logger, client} = context;
    Object.assign(global, context);
    const blobStore = require(config.blobStoreType)(config.blobStore);
    if (false) {
        const [snapshot] = await multiExecAsync(client, multi => {
            multi.hget('re8:h', 'snapshot');
        });
    }
    while (true) {
        const [key, snapshot] = await multiExecAsync(client, multi => {
            multi.brpoplpush('re8:key:q', 're8:busy:key:q', 1);
        });
        if (!key) {
            if (config.exit === 'empty') {
                break;
            }
            continue;
        }
        if (key === 'none') {
            break;
        }
        try {
            const timestamp = Date.now();
            const keyPath = pathFormat.keyPath(key);
            const [modtimeString, psha] = await multiExecAsync(client, multi => {
                multi.hget(`re8:modtime:h`, key);
                multi.hget(`re8:sha:h`, key);
            });
            const content = await client.getAsync(key);
            if (!content) {
                await removeAsync(blobStore, keyPath);
                if (!psha) {
                    continue;
                } else if (modtimeString) {
                    const modtime = parseInt(modtimeString);
                    if (modtime >= timestamp) {
                        timestamp = modtime + 1;
                    }
                }
                logger.debug({keyPath});
                await multiExecAsync(client, multi => {
                    multi.hset(`re8:modtime:h`, key, timestamp);
                    multi.hdel(`re8:sha:h`, key);
                    multi.hdel(`re8:${config.snapshot}:sha:h`, key);
                    multi.zadd(`re8:${config.snapshot}:key:${key}:z`, timestamp, timestamp);
                    multi.lrem('re8:busy:key:q', 1, key);
                    if (config.outq) {
                        multi.lpush(config.outq, key);
                    }
                });
            } else {
                const sha = pathFormat.urlSha(crypto.createHash('sha1').update(content).digest('base64'));
                if (sha === psha) {
                    continue;
                } else if (modtimeString) {
                    const modtime = parseInt(modtimeString);
                    if (modtime >= timestamp) {
                        timestamp = modtime + 1;
                    }
                }
                const timestampPath = pathFormat.timestampPath(key, new Date(timestamp));
                const shaPath = pathFormat.shaPath(key, sha);
                logger.debug({keyPath, shaPath, timestampPath, sha, timestamp}, JSON.parse(content));
                const gzipped = await gzipAsync(content);
                await writeAsync(blobStore, keyPath, gzipped);
                await writeAsync(blobStore, timestampPath, gzipped);
                await writeAsync(blobStore, shaPath, gzipped);
                await multiExecAsync(client, multi => {
                    multi.hset(`re8:modtime:h`, key, timestamp);
                    multi.hset(`re8:sha:h`, key, sha);
                    multi.hset(`re8:${config.snapshot}:sha:h`, key, sha);
                    multi.zadd(`re8:${config.snapshot}:key:${key}:z`, timestamp, sha);
                    multi.lrem('re8:busy:key:q', 1, key);
                    if (config.outq) {
                        multi.lpush(config.outq, key);
                    } else if (config.expire) {
                        multi.expire(key, config.expire);
                    } else if (config.action === 'delete'){
                        multi.del(key);
                    }
                });
            }
        } catch (err) {
            if (err.name === 'DataError') {
                console.error(err.message, err.data);
            } else {
                console.error(err);
            }
        } finally {
        }
    }
    logger.info('exit');
};
