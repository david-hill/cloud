function cleanup {
  rc=0
  if [ -e index.html ]; then
    rm -rf index.html
    rc=$?
  fi
  if [ $rc -eq 0 ]; then
    if [ -e tmp/version ]; then
      rm -rf tmp/version
      rc=$?
    fi
  fi
  return $rc
}
function makefolders {
  rc=0
  if [ ! -e backup ]; then
    mkdir backup
    rc=$?
  fi
  if [ $rc -eq 0 ]; then
    if [ ! -e tmp ]; then
      mkdir tmp
      rc=$?
    fi
  fi
  return $rc
}
function backupfiles {
  rc=0
  if [[ ! $cversion =~ empty ]]; then
    if [ ! -e backup/$cversion ]; then
      mkdir backup/$cversion
      rc=$?
    fi
    if [ $rc -eq 0 ]; then
      mv $p backup/$cversion/
      rc=$?
    fi
  fi
  return $rc
}
function getfiles {
  rc=0
  for p in $(cat index.html | grep .tar | awk -F\" '{ print $8 }' | grep -v "\.[0-9]$"); do
    if [ -e $p ]; then
      if [[ $nversion =~ $cversion ]]; then
        echo "Nothing to do" > /dev/null
      else
        backupfiles
        rc=$?
        if [ $rc -eq 0 ]; then
          wget -q $wpath$p
          rc=$?
        fi
      fi
    else
      wget -q $wpath$p
      rc=$?
    fi
    if [ $rc -ne 0 ]; then
      break
    fi
  done
  return $rc
}
function getversions {
  nversion=$(cat tmp/version)
  if [ -e version ]; then
    cversion=$(cat version)
  else
    cversion='empty'
  fi
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
      makefolders
      rc=$?
      if [ $rc -eq 0 ]; then
        cd tmp
        wget -q ${wpath}version > /dev/null
        rc=$?
        cd ..
        if [ $rc -eq 0 ]; then
          getversions
          getfiles
          rc=$?
          if [ $rc -eq 0 ]; then
            if [[ ! $nversion =~ $cversion ]]; then
              rm -fr version
              mv tmp/version .
              rc=$?
            fi
          fi
        fi
      fi
    fi
  fi
  return $rc
}

get_images http://rhos-release.virt.bos.redhat.com/puddle-images/8.0/latest-images/
exit $?
