#!/bin/bash

source functions
source_rc setup.cfg
<<<<<<< HEAD
if [ -e overcloudrc.v3 ]; then
  source overcloudrc.v3
else
  source overcloudrc
fi
=======
source_rc overcloudrc
>>>>>>> 2b7a33b... Load overcloudrc.v3 if it's present instead of overcloudrc
rc=0

version="0.3.5"
imagename="cirros-${version}-x86_64-disk.img"
primaryurl="http://download.cirros-cloud.net/$version/$imagename"
alternateurl="https://github.com/sshnaidm/cirros-mirror/raw/master/$imagename"

if [ ! -d images ]; then
  mkdir images
fi

if [ ! -e images/$imagename ]; then
  cd images
  startlog "Downloading cirros image"
  wget $primaryurl -O $imagename 2>>$stderr 1>>$stdout
  rc=$?
  cd ..
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    cd images
    wget $alternateurl -O $imagename 2>>$stderr 1>>$stdout
    rc=$?
    cd ..
    if [ $rc -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
    fi
  fi
fi

if [ $rc -eq 0 ]; then
  startlog "Listing glance image"
  glance image-list | grep -q $imagename
  if [ $? -eq 0 ]; then
    endlog "done"
    rc=0
  else
    endlog "done"
    startlog "Creating glance image"
    glance image-create --name "$imagename" --file images/$imagename --disk-format qcow2 --container-format bare --is-public True --progress 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -ne 0 ]; then
      glance image-create --name "$imagename" --file images/$imagename --disk-format qcow2 --container-format bare --visibility public --progress 2>>$stderr 1>>$stdout
      rc=$?
    fi
  fi
fi

if [ $rc -ne 0 ]; then
  endlog "error"
else
  endlog "done"
fi
exit $rc
