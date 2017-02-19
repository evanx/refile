
set -u -e 

docker build -t re8 https://github.com/evanx/re8.git

for container in `docker ps -q -f name=re8`
do
  docker rm -f $container
done

docker run --name re8 -d \
  --network=host \
  --restart unless-stopped \
  -v /opt/volumes/re8/data:/data \
  -e NODE_ENV=production \
  -e host=localhost \
  -e expire=1 \
  re8
