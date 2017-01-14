
const assert = require('assert');
const fetch = require('node-fetch');
const lodash = require('lodash');
const Promise = require('bluebird');
const formatElapsed = require('../components/formatElapsed');
const formatTime = require('../components/formatTime');

require('../components/redisApp')(require('./meta')).then(main);

const state = {};

async function main(context) {
    Object.assign(global, context);
    logger.level = config.loggerLevel;
    try {
    } catch (err) {
        console.error(err);
    } finally {
    }
}

async function subscribeEnd({endChannel, endMessage}) {
    state.clientEnd = redis.createClient(config.redisUrl);
    state.clientEnd.on('message', (channel, message) => {
        if (channel === endChannel) {
            if (message === endMessage) {
                end();
            }
        }
    });
    state.clientEnd.subscribe(endChannel);
}

async function end() {
    client.quit();
    state.clientEnd && state.clientEnd.quit();
}
