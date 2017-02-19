
  redis-cli keys 're8:*'
  for key in `redis-cli keys 're8:*:s'`
  do
    echo $key
    redis-cli smembers $key
    echo
  done
  for key in `redis-cli keys 're8:*:h'`
  do
    echo $key
    redis-cli hgetall $key
    echo
  done
  for key in `redis-cli keys 're8:*:z'`
  do
    echo $key
    redis-cli zrange $key 0 10 withscores
    echo
  done
