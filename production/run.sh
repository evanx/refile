
docker build -t reo https://github.com/evanx/reo
docker rm -f `docker ps -q -f name=reo`
docker run --name $name -d \
  --network=host \
  --restart unless-stopped \
  -v /opt/volumes/reo/data:/data \
  -e NODE_ENV=production \
  reo
