
const crypto = require('crypto');
const lodash = require('lodash');

const urlSha = sha => sha.replace(/=+$/, '').replace(/\//g, '-');

const key = key => key.replace(/\W/g, '-')

const keyPath = key => {
    const sha = urlSha(crypto.createHash('sha1').update(key).digest('base64'));
    return [
        'key',
        sha.substring(0, 3),
        sha.slice(-3),
        [
            key.replace(/\W/, '-'),
            'json'
        ].join('.')
    ].join('/');
};

const shaPath = (key, sha) => {
    sha = urlSha(sha);
    return [
        'sha',
        sha.substring(0, 3),
        sha.slice(-3),
        [
            sha,
            key.replace(/\W/, '-'),
            'json',
            'gz'
        ].join('.')
    ].join('/');
};

const timestampPath = (key, date) => {
    const dateString = date.toISOString();
    return [
        'time',
        dateString.substring(0, 10),
        dateString.substring(11, 19).replace(/:/, 'h').replace(/:/, 'm'),
        dateString.substring(20, 23),
        [
            key.replace(/\W/, '-'),
            'json',
            'gz'
        ].join('.')
    ].join('/');
};

module.exports = {urlSha, key, keyPath, timestampPath, shaPath}
