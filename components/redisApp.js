
const redis = require('redis');
const bluebird = require('bluebird');
const multiExecAsync = require('./multiExecAsync');
const reduceMetas = require('./reduceMetas');

bluebird.promisifyAll(redis.RedisClient.prototype);
bluebird.promisifyAll(redis.Multi.prototype);

module.exports = async metas => {
    console.log(`redisApp {${Object.keys(metas).join(', ')}}`);
    try {
        const configRedis = reduceMetas(metas, process.env, {required: false});
        const configKey = [configRedis.namespace, 'config'].join(':');
        console.log({configRedis, configKey});
        const client = redis.createClient(configRedis.redisUrl);
        const [configHashes] = await multiExecAsync(client, multi => {
            multi.hgetall(configKey);
        });
        console.log({configHashes}, Object.assign(configRedis, configHashes));
        const config = reduceMetas(metas, Object.assign(configRedis, configHashes));
        const logger = require('./redisLogger')(config, redis);
        return {redis, client, logger, config};
    } catch (err) {
        console.error(err.message);
        process.exit(1);
    }
};
