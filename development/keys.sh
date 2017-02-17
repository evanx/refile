
  redis-cli keys 'reo:*'
  for key in `redis-cli keys 'reo:*:s'`
  do
    echo $key
    redis-cli smembers $key
    echo
  done
  for key in `redis-cli keys 'reo:*:h'`
  do
    echo $key
    redis-cli hgetall $key
    echo
  done
  for key in `redis-cli keys 'reo:*:z'`
  do
    echo $key
    redis-cli zrange $key 0 10 withscores
    echo
  done
