#!/bin/bash

source setup.cfg
source functions

function create_overcloud {
  if [ -z $cephscale ] || [ -z $controlscale ] || [ -z $computescale ]; then
    rc=255;
  else
    openstack_oc_deploy
    rc=$?
  fi
  return $rc
}
delete_overcloud
rc=$?
if [ $rc -ne 0 ]; then
  create_overcloud
  rc=$?
  if [ $? -eq 0 ]; then
    test_overcloud
    rc=$?
  else 
    echo "Overcloud creation failed..."
  fi
else
  echo "Overcloud deletion failed..."
fi
exit $rc
