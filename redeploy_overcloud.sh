#!/bin/bash

source functions

source_rc setup.cfg
source_rc /home/stack/stackrc

function restart_services {
  which openstack-service 2>>/dev/null 1>>/dev/null
  if [ $? -eq 0 ]; then
    startlog "Restarting all openstack services"
    sudo bash -c "openstack-service restart 2>>/dev/null 1>>/dev/null"
    if [ $? -eq 0 ]; then
      endlog "done"
      rc=0
    else
      endlog "error"
      rc=1
    fi
  fi
  return $rc
}
function create_overcloud {
  openstack_oc_deploy
  rc=$?
  return $rc
}

delete_overcloud
rc=$?
if [ $rc -eq 0 ]; then
  restart_services
  rc=$?
  if [ $rc -eq 0 ]; then
    create_overcloud
    rc=$?
    if [ $rc -eq 0 ]; then
      test_overcloud
      rc=$?
    fi
  fi
fi
exit $rc
