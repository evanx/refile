
set -u -e 

docker build -t reo https://github.com/evanx/reo.git

for container in `docker ps -q -f name=reo`
do
  docker rm -f $container
done

docker run --name $name -d \
  --network=host \
  --restart unless-stopped \
  -v /opt/volumes/reo/data:/data \
  -e NODE_ENV=production \
  reo
