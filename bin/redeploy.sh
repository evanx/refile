
set -u -e

[ $# -eq 1 ]
home=$1

docker build -t refile https://github.com/evanx/refile.git

for container in `docker ps -q -f name=refile`
do
  docker rm -f $container
done

docker run --name refile -d \
  --restart unless-stopped \
  --network=host \
  -v $home/volumes/refile/data:/data \
  -e NODE_ENV=$NODE_ENV \
  -e host=localhost \
  -e expire=8 \
  refile
