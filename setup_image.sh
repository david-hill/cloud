#!/bin/bash

source functions
source_rc setup.cfg
source overcloudrc
rc=0

if [ ! -d images ]; then
  mkdir images
fi

if [ ! -e images/cirros-0.3.4-x86_64-disk.img ]; then
  cd images
  startlog "Downloading cirros image"
  wget -q http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img > /dev/null
  rc=$?
  cd ..
fi

if [ $rc -eq 0 ]; then
  endlog "done":
  startlog "Creating glance image"
  glance image-create --name "cirros-0.3.4-x86_64" --file images/cirros-0.3.4-x86_64-disk.img --disk-format qcow2 --container-format bare --is-public True --progress > /dev/null
  rc=$?
fi

if [ $rc -ne 0 ]; then
  endlog "error"
else
  endlog "done"
fi
exit $rc
