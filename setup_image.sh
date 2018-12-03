#!/bin/bash

source functions
source_rc setup.cfg
source_rc overcloudrc
rc=0

version="0.4.0"
imagename="cirros-${version}-x86_64-disk.img"
primaryurl="http://download.cirros-cloud.net/$version/$imagename"
alternateurl="https://github.com/sshnaidm/cirros-mirror/raw/master/$imagename"

if [ ! -d images ]; then
  mkdir images
fi

if [ ! -e images/$imagename ]; then
  startlog "Downloading cirros image"
  wget $primaryurl -O images/$imagename 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    wget $alternateurl -O images/$imagename 2>>$stderr 1>>$stdout
    rc=$?
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
      if [ $rc -eq 0 ]; then
        endlog "done"
      else
        endlog "error"
      fi
    else
      endlog "done"
    fi
  fi
fi

exit $rc
