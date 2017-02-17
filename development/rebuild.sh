
  docker build -t reo https://github.com/evanx/reo.git
  if [ -n "$DHUSER"]
  then
    docker tag reo $DHUSER/reo
    docker push $DHUSER/reo
  fi
