(
  set -u -e -x
  mkdir -p tmp
  mkdir -p $HOME/volumes/r8/
  for name in r8-redis r8-app r8-decipher r8-encipher
  do
    if docker ps -a -q -f "name=/$name" | grep '\w'
    then
      docker rm -f `docker ps -a -q -f "name=/$name"`
    fi
  done
  sleep 1
  if docker network ls -q -f name=^r8-network | grep '\w'
  then
    docker network rm r8-network
  fi
  docker network create -d bridge r8-network
  redisContainer=`docker run --network=r8-network \
      --name r8-redis -d redis`
  redisHost=`docker inspect $redisContainer |
      grep '"IPAddress":' | tail -1 | sed 's/.*"\([0-9\.]*\)",/\1/'`
  dd if=/dev/urandom bs=32 count=1 > $HOME/volumes/r8/spiped-keyfile
  decipherContainer=`docker run --network=r8-network \
    --name r8-decipher -v $HOME/volumes/r8/spiped-keyfile:/spiped/key:ro \
    -d spiped \
    -d -s "[0.0.0.0]:6444" -t "[$redisHost]:6379"`
  decipherHost=`docker inspect $decipherContainer |
    grep '"IPAddress":' | tail -1 | sed 's/.*"\([0-9\.]*\)",/\1/'`
  encipherContainer=`docker run --network=r8-network \
    --name r8-encipher -v $HOME/volumes/r8/spiped-keyfile:/spiped/key:ro \
    -d spiped \
    -e -s "[0.0.0.0]:6333" -t "[$decipherHost]:6444"`
  encipherHost=`docker inspect $encipherContainer |
    grep '"IPAddress":' | tail -1 | sed 's/.*"\([0-9\.]*\)",/\1/'`
  redis-cli -h $encipherHost -p 6333 set user:evanxsummers '{"twitter":"evanxsummers"}'
  redis-cli -h $encipherHost -p 6333 lpush r8:key:q user:evanxsummers
  redis-cli -h $encipherHost -p 6333 llen r8:key:q
  appContainer=`docker run --name r8-app -d \
    --network=r8-network \
    -v $HOME/volumes/r8/data:/data \
    -e host=$encipherHost \
    -e port=6333 \
    evanxsummers/r8`
  sleep 2
  redis-cli -h $encipherHost -p 6333 llen r8:key:q
  docker logs $appContainer
  find $HOME/volumes/r8/data
  #docker rm -f r8-redis r8-app r8-decipher r8-encipher
  #docker network rm r8-network
)
