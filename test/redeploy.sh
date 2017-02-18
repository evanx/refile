
name=`basename $PWD`

docker build -t $name https://github.com/evanx/$name.git
docker rm -f `docker ps -q -f name=$name`
docker run --name $name -d \
  --network=host 
  --restart unless-stopped \
  -e NODE_ENV=test \
  $name
