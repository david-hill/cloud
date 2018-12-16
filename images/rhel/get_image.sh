function cleanup {
  rc=0
  if [ -e index.html ]; then
    rm -rf index.html
    rc=$?
  fi
  return $rc
}

function getversion {
  version=$(cat index.html  | grep DIR | tail -5  | head -1 | awk -F\" '{ print $6 }' | sed -e 's/\///')
}

function getfiles {
  local url=$1
  rc=255
  for p in $(cat index.html  | grep "\.qcow2" | tail -1  | awk -F \" '{ print $6 }'); do
    if [ ! -e $p ]; then
      wget -q $url/$p
      rc=$?
    else
      rc=0
    fi
  done
  return $rc
}

function getindex {
  local rc=255
  local url=$1
  if [ -e index.html ]; then
    rm -rf index.html
    rc=$?
  fi
  if [ $? -eq 0 ]; then
    wget -q $url
    rc=$?
  fi
  return $rc
}

function get_images {
  rc=255
  wpath=$1
  rc=$?
  if [ $rc -eq 0 ]; then
    for release in $releases; do
      cleanup
      wget -q $wpath${release}/
      rc=$?
      if [ $rc -eq 0 ]; then
        getversion
        getindex "$wpath$release/$version/images/"
        rc=$?
        if [ $rc -eq 0 ]; then
          getfiles "$wpath$release/$version/images/"
          rc=$?
        fi
      fi
    done
  fi
  return $rc
}
releases="7.2 7.3 7.4 7.5 7.6 7.7"
#get_images http://download.eng.bos.redhat.com/brewroot/packages/rhel-guest-image/
get_images http://download-node-02.eng.bos.redhat.com/brewroot/packages/rhel-guest-image/
exit $?
