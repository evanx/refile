
  ls -l `find r8data | grep json`
  for json in `find r8data | grep json$`
  do
    echo $json
    cat $json
    echo
  done
  for gz in `find r8data | grep json.gz$`
  do
    echo $gz
    zcat $gz
    echo
  done
