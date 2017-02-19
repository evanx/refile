(
  set -u -e -x
  mkdir -p tmp
  mkdir -p $HOME/volumes/re8/
  for name in re8-redis re8-app re8-decipher re8-encipher
  do
    if docker ps -a -q -f "name=/$name" | grep '\w'
    then
      docker rm -f `docker ps -a -q -f "name=/$name"`
    fi
  done
  sleep 1
  if docker network ls -q -f name=^re8-network | grep '\w'
  then
    docker network rm re8-network
  fi
  docker network create -d bridge re8-network
  redisContainer=`docker run --network=re8-network \
      --name re8-redis -d redis`
  redisHost=`docker inspect $redisContainer |
      grep '"IPAddress":' | tail -1 | sed 's/.*"\([0-9\.]*\)",/\1/'`
  dd if=/dev/urandom bs=32 count=1 > $HOME/volumes/re8/spiped-keyfile
  decipherContainer=`docker run --network=re8-network \
    --name re8-decipher -v $HOME/volumes/re8/spiped-keyfile:/spiped/key:ro \
    -d spiped \
    -d -s "[0.0.0.0]:6444" -t "[$redisHost]:6379"`
  decipherHost=`docker inspect $decipherContainer |
    grep '"IPAddress":' | tail -1 | sed 's/.*"\([0-9\.]*\)",/\1/'`
  encipherContainer=`docker run --network=re8-network \
    --name re8-encipher -v $HOME/volumes/re8/spiped-keyfile:/spiped/key:ro \
    -d spiped \
    -e -s "[0.0.0.0]:6333" -t "[$decipherHost]:6444"`
  encipherHost=`docker inspect $encipherContainer |
    grep '"IPAddress":' | tail -1 | sed 's/.*"\([0-9\.]*\)",/\1/'`
  redis-cli -h $encipherHost -p 6333 set user:evanxsummers '{"twitter":"evanxsummers"}'
  redis-cli -h $encipherHost -p 6333 lpush re8:key:q user:evanxsummers
  redis-cli -h $encipherHost -p 6333 llen re8:key:q
  appContainer=`docker run --name re8-app -d \
    --network=re8-network \
    -v $HOME/volumes/re8/data:/data \
    -e host=$encipherHost \
    -e port=6333 \
    evanxsummers/re8`
  sleep 2
  redis-cli -h $encipherHost -p 6333 llen re8:key:q
  docker logs $appContainer
  find ~/volumes/re8/data | grep '.gz$'
  zcat `find ~/volumes/re8/data | grep '.gz$' | tail -1`
  #docker rm -f re8-redis re8-app re8-decipher re8-encipher
  #docker network rm re8-network
)
