#!/bin/bash

source functions
source_rc setup.cfg
if [ -e overcloudrc.v3 ]; then
  source overcloudrc.v3
else
  source overcloudrc
fi
rc=0

if [ ! -d images ]; then
  mkdir images
fi

if [ ! -e images/cirros-0.3.4-x86_64-disk.img ]; then
  cd images
  startlog "Downloading cirros image"
  wget -q http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img 2>>$stderr 1>>$stdout
  rc=$?
  cd ..
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
fi

if [ $rc -eq 0 ]; then
  startlog "Listing glance image"
  glance image-list | grep -q cirros-0.3.4-x86_64
  if [ $? -eq 0 ]; then
    endlog "done"
    rc=0
  else
    endlog "done"
    startlog "Creating glance image"
    glance image-create --name "cirros-0.3.4-x86_64" --file images/cirros-0.3.4-x86_64-disk.img --disk-format qcow2 --container-format bare --is-public True --progress 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -ne 0 ]; then
      glance image-create --name "cirros-0.3.4-x86_64" --file images/cirros-0.3.4-x86_64-disk.img --disk-format qcow2 --container-format bare --visibility public --progress 2>>$stderr 1>>$stdout
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
