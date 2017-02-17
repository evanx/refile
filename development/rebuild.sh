
  docker build -t r8 https://github.com/evanx/r8.git
  if [ -n "$DHUSER"]
  then
    docker tag r8 $DHUSER/r8
    docker push $DHUSER/r8
  fi
