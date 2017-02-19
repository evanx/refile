
  docker build -t re8 https://github.com/evanx/re8.git
  if [ -n "$DHUSER"]
  then
    docker tag re8 $DHUSER/re8
    docker push $DHUSER/re8
  fi
