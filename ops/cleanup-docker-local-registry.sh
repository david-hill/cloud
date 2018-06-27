doit=0
dockerurl=192.0.2.1:8787
#deletetags="12.0-20180522.1 12.0-20180529.1"
#deletetags="12.0-20180522.1"
deletetags="12.0-20180529.1"

while getopts ":f" opt; do
  case $opt in
    f) doit=1 ;;
    \?) echo Warning: unknown argument specified 1>&2 ;;
  esac
done

function gettags {
   tags=$( curl -s ${dockerurl}/v2/$p/tags/list )
}

function deleteimages {
  for image in $( docker images | grep $tag | awk '{ print $3 }' ); do
    if [ $doit -eq 1 ]; then
      docker rmi -f $image
    else
      echo docker rmi -f $image
    fi
  done
}

function deletemanifests {

  sha=$( curl -v ${dockerurl}/v2/$p/manifests/$tag -H "Accept: application/vnd.docker.distribution.manifest.v2+json" 2>&1 | grep Docker-Content-Digest | awk -F: '{ print $3 }' | sed -e 's/\r//g' )
  if [ $doit -eq 1 ]; then
    curl -s -X DELETE -v ${dockerurl}/v2/$p/manifests/sha256:$sha
  else
    echo curl -s -X DELETE -v ${dockerurl}/v2/$p/manifests/sha256:$sha
  fi
}

catalog=$( curl -s $dockerurl/v2/_catalog )

for tag in $deletetags ; do
  deleteimages
  for p in $(echo $catalog | sed -e 's/,/\n/g' | sed -e 's/repositories//' -e 's/"//g' -e 's/{:\[//g' -e 's/\]}//g' ); do                                                                    
    gettags
    if [[ "$tags" =~ "$tag" ]]; then
      deletemanifests
    fi
  done
done

# The following need to be present in /etc/docker-distribution/registry/config.yml
# storage:
#   delete:
#     enabled: true

registry garbage-collect /etc/docker-distribution/registry/config.yml
