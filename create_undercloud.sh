#!/bin/bash

source functions
source setup.cfg
source creds.cfg
if [ -e "creds.cfg.local" ]; then
  source creds.cfg.local
fi

validate_env
if [ ! -d tmp ]; then
  mkdir tmp
fi

if [ $? -eq 0 ]; then
  memory=$undercloudmemory
  type=undercloud
  inc=rhosp8
  vmname="${type}-${inc}"
  if [ -e "S01customize.local" ]; then
    cp S01customize.local tmp/S01customize
  else    
    cp S01customize tmp/S01customize
  fi
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
else
  echo "Please run this on baremetal..."
fi
