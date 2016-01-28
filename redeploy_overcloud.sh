#!/bin/bash

source setup.cfg
source functions

function delete_overcloud {
  echo "Deleting overcloud...."
  heat=$( heat stack-list | grep overcloud )
  if [ ! -z "$heat" ]; then
    heat stack-delete overcloud
    while [ ! -z "$heat" ]; do
      heat=$( heat stack-list | grep overcloud )
      echo -n "."
      if [[ "$heat" =~ FAILED ]]; then
        echo "Stack deletion failed... retrying!"
        heat stack-delete overcloud
      fi
    done
  fi
}

function create_overcloud {
  if [ -z $cephscale ] || [ -z $controlscale ] || [ -z $computescale ]; then
    rc=255;
  else
    openstack overcloud deploy --templates ~/templates/my-overcloud -e ~/templates/my-overcloud/environments/network-isolation.yaml -e ~/templates/network-environment.yaml -e ~/templates/storage-environment.yaml --control-scale $controlscale --compute-scale $computescale --ceph-storage-scale $cephscale --control-flavor control --compute-flavor compute --ceph-storage-flavor ceph-storage --ntp-server pool.ntp.org --neutron-network-type vxlan --neutron-tunnel-types vxlan
    rc=$?
  fi
}
delete_overcloud
create_overcloud
test_overcloud
exit $rc
