#!/bin/bash

source setup.cfg
source functions

function create_overcloud {
  if [ -z $cephscale ] || [ -z $controlscale ] || [ -z $computescale ]; then
    rc=255;
  else
    openstack overcloud deploy --templates ~/templates/my-overcloud -e ~/templates/my-overcloud/environments/network-isolation.yaml -e ~/templates/network-environment.yaml -e ~/templates/storage-environment.yaml --control-scale $controlscale --compute-scale $computescale --ceph-storage-scale $cephscale --control-flavor control --compute-flavor compute --ceph-storage-flavor ceph-storage --ntp-server pool.ntp.org --neutron-network-type vxlan --neutron-tunnel-types vxlan
    rc=$?
  fi
  return $rc
}
delete_overcloud
create_overcloud
rc=$?
if [ $? -eq 0 ]; then
  test_overcloud
  rc=$?
fi
exit $rc
