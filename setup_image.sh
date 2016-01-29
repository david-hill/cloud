#!/bin/bash

rc=0

if [ ! -d images ]; then
  mkdir images
fi

if [ ! -e images/cirros-0.3.4-x86_64-disk.img ]; then
  cd images
  wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
  rc=$?
  cd ..
fi

if [ $rc -eq 0 ]; then
  glance image-create --name "cirros-0.3.4-x86_64" --file images/cirros-0.3.4-x86_64-disk.img --disk-format qcow2 --container-format bare --is-public True --progress
  rc=$?
else
  echo "Wget failed!"
fi

exit $rc
