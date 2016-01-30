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
if [ $rc -ne 0 ]; then
  sudo openstack-service restart
  rc=$?
  if [ $? -eq 0 ]; then
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
