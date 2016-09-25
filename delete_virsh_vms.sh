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
  if [[ $type =~ control ]]; then
    max=$controlscale
  elif [[ $type =~ ceph ]]; then
    max=$cephscale
  else
    max=$computescale
  fi
  
  while [ $inc -lt $max ]; do
    output=$(sudo virsh list --all | grep "$type-$inc-$releasever" | awk '{ print $2 }')
    for server in $output; do
      if [[ "$server" =~ $type-$inc ]]; then 
        for snap in $(sudo virsh snapshot-list $server | egrep "running|shut off" | awk '{ print $1 }'); do
          sudo virsh snapshot-delete $server $snap 2>>$stderr 1>>$stdout
        done
        sudo virsh destroy $server 2>>$stderr 1>>$stdout
        sudo virsh undefine $server 2>>$stderr 1>>$stdout
      else
        ip=$(ip addr)
        if [[ ! "$ip" =~ $kvmhost ]]; then
          rserver=$(ssh root@$kvmhost "sudo virsh list --all | grep $type-$inc-$releasever | awk '{ print \$2 }'")
          for tserver in $rserver; do
            if [[ "$tserver" =~ $type-$inc ]]; then
              ssh root@$kvmhost "sudo virsh destroy $tserver" 2>>$stderr 1>>$stdout
              ssh root@$kvmhost "sudo virsh undefine $tserver" 2>>$stderr 1>>$stdout
            fi
          done
        fi
      fi
    done
    inc=$(expr $inc + 1)
  done
}

function cleanup {
  if [ -e /home/stack/instackenv.json ]; then
    sudo rm -rf /home/stack/instackenv.json
  fi
}
delete_vms control
delete_vms ceph
delete_vms compute
cleanup
