
set -u -e

docker build -t refile https://github.com/evanx/refile.git

for container in `docker ps -q -f name=refile`
do
  docker rm -f $container
done

docker run --name refile -d \
  --network=host \
  --restart unless-stopped \
  -v /refiledata:/data \
  -e NODE_ENV=$NODE_ENV \
  -e host=localhost \
  -e expire=1 \
  refile
