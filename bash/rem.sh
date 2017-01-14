
  redis-cli del test12345
  redis-cli lpush r8:key:q test12345
  node --harmony lib/index.js
