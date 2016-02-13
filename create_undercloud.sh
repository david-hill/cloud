#!/bin/bash

source functions
source setup.cfg
source creds.cfg
if [ -e "creds.cfg.local" ]; then
  source creds.cfg.local
fi

validate_env
if [ $? -eq 0 ]; then
  memory=$undercloudmemory
  type=undercloud
  inc=rhosp8
  vmname="${undercloud}-${inc}"
  sudo cp /home/dhill/VMs/rhel-guest-image-7.2-20151102.0.x86_64.qcow2 /home/dhill/VMs/${vmname}.qcow2
  sudo qemu-img resize /home/dhill/VMs/${vmname}.qcow2 30G
  sudo virt-customize -a /home/dhill/VMs/${vmname}.qcow2 --copy-in customize.service:/etc/systemd/system/ 
  sudo virt-customize -a /home/dhill/VMs/${vmname}.qcow2 --copy-in S01customize:/etc/rc.d/rc3.d/ --root-password password:$rootpasswd
  sudo virt-customize -a /home/dhill/VMs/${vmname}.qcow2 --link /etc/systemd/system/customize.service:/etc/systemd/system/multi-user.target.wants/customize.service

  tmpfile=$(mktemp)
  uuid=$(uuidgen)
  tpath='/home/dhill/VMs'
  gen_macs
  gen_xml
  create_domain
  cleanup
else
  echo "Please run this on baremetal..."
fi
