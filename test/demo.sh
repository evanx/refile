(
  set -u -e -x
  mkdir -p tmp
  for name in test-r8-redis test-r8-app test-r8-decipher test-r8-encipher
  do
    if docker ps -q -f "name=/$name" | grep "$name"
    then
      docker rm -f $name `docker ps -q -f "name=/$name"`
    fi
  done
  sleep 1
  if docker network ls | grep test-r8-network
  then
    docker network rm test-r8-network
  fi
  docker network create -d bridge test-r8-network
  redisContainer=`docker run --network=test-r8-network \
      --name test-r8-redis -d tutum/redis`
  password=`docker logs $redisContainer | grep '^\s*redis-cli -a' |
      sed -e 's/^\s*redis-cli -a \(\w*\) .*$/\1/'`
  redisHost=`docker inspect $redisContainer |
      grep '"IPAddress":' | tail -1 | sed 's/.*"\([0-9\.]*\)",/\1/'`
  dd if=/dev/urandom bs=32 count=1 > $HOME/tmp/test-spiped-keyfile
  decipherContainer=`docker run --network=test-r8-network \
    --name test-r8-decipher -v $HOME/tmp/test-spiped-keyfile:/spiped/key:ro \
    -d spiped \
    -d -s "[0.0.0.0]:6444" -t "[$redisHost]:6379"`
  decipherHost=`docker inspect $decipherContainer |
    grep '"IPAddress":' | tail -1 | sed 's/.*"\([0-9\.]*\)",/\1/'`
  encipherContainer=`docker run --network=test-r8-network \
    --name test-r8-encipher -v $HOME/tmp/test-spiped-keyfile:/spiped/key:ro \
    -d spiped \
    -e -s "[0.0.0.0]:6333" -t "[$decipherHost]:6444"`
  encipherHost=`docker inspect $encipherContainer |
    grep '"IPAddress":' | tail -1 | sed 's/.*"\([0-9\.]*\)",/\1/'`
  redis-cli -a $password -h $encipherHost -p 6333 set user:evanxsummers '{"twitter":"evanxsummers"}'
  docker run --name test-r8-app -f \
    --network=test-r8-network \
    -e host=$encipherHost -e port=6333 -e password=$password \
    -e evanxsummers/r8
  #docker rm -f test-r8-redis test-r8-app test-r8-decipher test-r8-encipher
  #docker network rm test-r8-network
)
