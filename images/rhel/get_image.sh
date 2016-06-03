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
  cleanup
  rc=$?
  if [ $rc -eq 0 ]; then
    wget -q $wpath 
    rc=$?
    if [ $rc -eq 0 ]; then
      getversion
      getindex "$wpath/$version/images/"
      rc=$?
      if [ $rc -eq 0 ]; then
        getfiles "$wpath/$version/images/"
        rc=$?
      fi
    fi
  fi
  return $rc
}

get_images http://download.eng.bos.redhat.com/brewroot/packages/rhel-guest-image/7.2/
exit $?
