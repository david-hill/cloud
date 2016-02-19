#!/bin/bash

source functions
source_rc setup.cfg

validate_env
if [ ! -d tmp ]; then
  mkdir tmp
fi

if [ $? -eq 0 ]; then
  memory=$undercloudmemory
  type=undercloud
  inc=0
  vmname="${type}-${inc}-${releasever}"
  if [ -e "S01customize.local" ]; then
    cp S01customize.local tmp/S01customize
  else    
    cp S01customize tmp/S01customize
  fi
  sed -i "s/rhosp8/$releasever/g" tmp/S01customize
  vpnip=$(ip addr | grep inet | grep 10 | awk ' { print $2 }' | sed -e 's#/32##')
  sudo iptables -t nat -I POSTROUTING -s 192.168.122.0/24 -d 10.0.0.0/8 -o wlp3s0 -j SNAT --to-source $vpnip
  sudo cp /home/dhill/VMs/rhel-guest-image-7.2-20151102.0.x86_64.qcow2 /home/dhill/VMs/${vmname}.qcow2
  sudo qemu-img resize /home/dhill/VMs/${vmname}.qcow2 30G
  sudo virt-customize -a /home/dhill/VMs/${vmname}.qcow2 --copy-in customize.service:/etc/systemd/system/ 
  sudo virt-customize -a /home/dhill/VMs/${vmname}.qcow2 --copy-in tmp/S01customize:/etc/rc.d/rc3.d/ --root-password password:$rootpasswd
  sudo virt-customize -a /home/dhill/VMs/${vmname}.qcow2 --link /etc/systemd/system/customize.service:/etc/systemd/system/multi-user.target.wants/customize.service

  tmpfile=$(mktemp)
  uuid=$(uuidgen)
  tpath='/home/dhill/VMs'
  gen_macs
  gen_xml
  create_domain
  start_domain
  cleanup

  down=1
  while [ $down -eq 1 ]; do
    ping -c 1 192.168.122.2
    up=$?
  done
  sshrc=1
  while [ $ssh -ne 0 ]; do
    ssh stack@192.168.122.2 'uptime'
    sshrc=$?
  done
  bash create_virsh_vms.sh

else
  echo "Please run this on baremetal..."
fi
