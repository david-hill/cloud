#!/bin/bash

source functions

source_rc setup.cfg
source_rc /home/stack/stackrc

function create_overcloud {
  openstack_oc_deploy
  rc=$?
  return $rc
}

delete_overcloud
rc=$?
if [ $rc -eq 0 ]; then
  startlog "Restarting all openstack services"
  sudo bash -c "openstack-service restart 2>&1 > /dev/null"
  rc=$?
  if [ $? -eq 0 ]; then
    endlog "done"
    create_overcloud
    rc=$?
    if [ $? -eq 0 ]; then
      test_overcloud
      rc=$?
    fi
  else
    endlog "error"
  fi
fi
exit $rc
