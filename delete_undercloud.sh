#!/bin/bash

source functions
source_rc setup.cfg

if [ ! -z $1 ]; then
  installtype=$1
  if [ ! -z $2 ]; then
    releasever=$2
  fi
fi

if [[ "$installtype" =~ all ]]; then
  releasever='*'
fi

function delete_vms {
  type=$1
  inc=0
  output=$(sudo virsh list --all | grep "$type-$inc-$releasever" | awk '{ print $2 }')
  if [ ! -z "${output}" ]; then
    for server in $output; do
      ssh stack@$undercloudip 'sudo subscription-manager unregister' 2>>$stderr 1>>$stdout
      for snap in $(sudo virsh snapshot-list $server | egrep "shut off|running" | awk '{ print $1 }'); do
        sudo virsh snapshot-delete $server $snap 2>>$stderr 1>>$stdout
      done
      sudo virsh destroy $server 2>>$stderr 1>>$stdout
      sudo virsh undefine $server 2>>$stderr 1>>$stdout
      sudo rm -rf /run/systemd/machines/*$type*$inc*$releasever*
      sudo rm -rf /run/systemd/transient/*$type*$inc*$releasever*
      sudo systemctl daemon-reload
    done
  fi
}

function cleanup {
  if [ -e /home/stack/instackenv.json-$releasever ]; then
    sudo rm -rf /home/stack/instackenv.json-$releasever
  fi
}
delete_vms undercloud
cleanup
