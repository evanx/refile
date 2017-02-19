
  user=`
    docker info 2>/dev/null | 
    grep ^Username | 
    sed 's/Username: \(.*\)/\1/'
  `
  docker build -t re8 https://github.com/evanx/re8.git
  docker tag re8 $user/re8
  docker push $user/re8
