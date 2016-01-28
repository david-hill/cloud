#!/bin/bash

source setup.cfg

if [ -z $cephscale ] || [ -z $controlscale ] || [ -z $computescale ]; then
  rc=255;
else
  openstack_oc_deploy
  rc=$?
fi

exit $rc
