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

function wait_for_vbmc_stop {
  server=$1
  rc=0
  cpttimeout=0
  while [ $rc -eq 0 ] && [ $cpttimeout -lt $timeout ]; do
    cpttimeout=$(( $cpttimeout + 1 ))
    sudo vbmc list | grep -q "$server.*running"
    rc=$?
    sleep 1
  done
}
function delete_bmc {
  type=$1
  which vbmc 2>>$stderr 1>>$stdout
  if [ $? -eq 0 ]; then
    inc=0
    if [[ $type =~ control ]]; then
      max=$controlscale
    elif [[ $type =~ ceph ]]; then
      max=$cephscale
    else
      max=$computescale
    fi
    while [ $inc -lt $max ]; do
      output=$(sudo vbmc list  | grep "$type-$inc-$releasever" | awk '{ print $2 }')
      for server in $output; do
        if [[ "$server" =~ $type-$inc ]]; then 
          pm_ip=$(sudo vbmc list | grep $server | awk '{ print $6 }')
          sudo ip addr del $pm_ip dev virbr0 2>>$stderr 1>>$stdout
          sudo vbmc stop $server 2>>$stderr 1>>$stdout
          wait_for_vbmc_stop $server
          sudo vbmc delete $server  2>>$stderr 1>>$stdout
        else
          ip=$(ip addr)
          if [[ ! "$ip" =~ $kvmhost ]]; then
            rserver=$(ssh root@$kvmhost "sudo vbmc list | grep $type-$inc-$releasever | awk '{ print \$2 }'")
            for tserver in $rserver; do
              if [[ "$tserver" =~ $type-$inc ]]; then
                ssh root@$kvmhost "sudo vbmc stop $tserver" 2>>$stderr 1>>$stdout
                ssh root@$kvmhost "sudo vbmc delete $tserver" 2>>$stderr 1>>$stdout
              fi
            done
          fi
        fi
      done
      inc=$(expr $inc + 1)
    done
  fi
}

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
        sudo rm -rf /run/systemd/machines/*$type*$inc*$releasever*
        sudo rm -rf /run/systemd/transient/*$type*$inc*$releasever*
        sudo systemctl daemon-reload
      else
        ip=$(ip addr)
        if [[ ! "$ip" =~ $kvmhost ]]; then
          rserver=$(ssh root@$kvmhost "sudo virsh list --all | grep $type-$inc-$releasever | awk '{ print \$2 }'")
          for tserver in $rserver; do
            if [[ "$tserver" =~ $type-$inc ]]; then
              ssh root@$kvmhost "sudo virsh destroy $tserver" 2>>$stderr 1>>$stdout
              ssh root@$kvmhost "sudo virsh undefine $tserver" 2>>$stderr 1>>$stdout
              ssh root@$kvmhost "sudo rm -rf /run/systemd/machines/*$type*$inc*$releasever*" 2>>$stderr 1>>$stdout
              ssh root@$kvmhost "sudo rm -rf /run/systemd/transient/*$type*$inc*$releasever*" 2>>$stderr 1>>$stdout
              ssh root@$kvmhost "sudo systemctl daemon-reload" 2>>$stderr 1>>$stdout
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
delete_bmc control
delete_bmc ceph
delete_bmc compute
delete_vms control
delete_vms ceph
delete_vms compute
cleanup
