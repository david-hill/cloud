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

function backup_images {
  file=$1
  curdate=$( date +'%Y%m%d%H' )
  if [ ! -d ../backup/$curdate ]; then
    mkdir -p ../backup/$curdate
  fi
  mv ../$file ../backup/$curdate
  mv ../$file.md5 ../backup/$curdate
}
function get_images {
  rc=255
  wpath=$1
  makefolders
  rc=$?
  if [ $rc -eq 0 ]; then
    cd tmp
    for file in $files; do
      wget -q ${wpath}/$file.md5 -O $file.md5
      if [ -e ../$file.md5 ]; then
        pver=$(cat ../$file.md5)
        cver=$(cat $file.md5)
        if [ ! "$pver" == "$cver" ]; then
          backup_images $file
          mv $file.md5 ../
          wget -q ${wpath}/$file -O ../$file
        fi
      else
        mv $file.md5 ../
        wget -q ${wpath}/$file -O ../$file
      fi
    done
    cd ..
  fi
  return $rc
}

files="ironic-python-agent.tar overcloud-full.tar"
if [ -e index.html ]; then
  rm -rf index.html
fi
wget -q "http://rhos-release.virt.bos.redhat.com/poodle-images/rhos-10/?C=M;O=A" -O index.html
version=$(cat index.html  | grep folder | tail -1 | awk -F\" '{ print $8 }')
get_images http://rhos-release.virt.bos.redhat.com/poodle-images/rhos-10/$version
exit $?
