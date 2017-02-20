
const crypto = require('crypto');

const key = "user:evanxsummes";
const hash = crypto.createHash('sha1').update(key).digest().toString(32);

console.log({key, hash});

