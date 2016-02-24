#!/bin/bash

source setup.cfg
source functions

function create_overcloud {
  openstack_oc_deploy
  rc=$?
  return $rc
}
delete_overcloud
rc=$?
if [ $rc -eq 0 ]; then
  startlog "Restaring all openstack services..."
  sudo bash -c "openstack-service restart > /dev/null"
  rc=$?
  if [ $? -eq 0 ]; then
    endlog "done"
    create_overcloud
    rc=$?
    if [ $? -eq 0 ]; then
      test_overcloud
      rc=$?
    else 
      echo "Overcloud creation failed..."
    fi
  fi
else
  echo "Overcloud deletion failed..."
fi
exit $rc
