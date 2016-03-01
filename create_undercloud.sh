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
  sudo pkill dnsmasq
  sed -i "s/rhosp8/$releasever/g" tmp/S01customize
  vpnip=$(ip addr | grep inet | grep 10 | awk ' { print $2 }' | sed -e 's#/32##')
  sudo iptables -t nat -I POSTROUTING -s 192.168.122.0/24 -d 10.0.0.0/8 -o wlp3s0 -j SNAT --to-source $vpnip
  startlog "Copying base image"
  sudo cp /home/dhill/VMs/rhel-guest-image-7.2-20151102.0.x86_64.qcow2 /home/dhill/VMs/${vmname}.qcow2
  endlog "done"
  startlog "Resizing base disk"
  sudo qemu-img resize /home/dhill/VMs/${vmname}.qcow2 30G > /dev/null
  endlog "done"
  startlog "Customizing image"
  sed -i "s/###MINORVER###/$minorver/g" tmp/S01customize
  sed -i "s/###RELEASEVER###/$releasever/g" tmp/S01customize
  sudo virt-customize -a /home/dhill/VMs/${vmname}.qcow2 --copy-in customize.service:/etc/systemd/system/ --copy-in tmp/S01customize:/etc/rc.d/rc3.d/ --copy-in S01loader:/etc/rc.d/rc3.d/ --root-password password:$rootpasswd --link /etc/systemd/system/customize.service:/etc/systemd/system/multi-user.target.wants/customize.service > /dev/null
  endlog "done"

  tmpfile=$(mktemp)
  uuid=$(uuidgen)
  tpath='/home/dhill/VMs'
  vcpus=2
  gen_macs
  gen_xml
  create_domain
  start_domain
  cleanup

  startlog "Waiting for VM to come up"
  down=1
  while [ $down -eq 1 ]; do
    echo -n "."
    ping -c 1 $undercloudip > /dev/null
    down=$?
    sleep 1
  done
  endlog "done"
  startlog "Waiting for SSH to come up"
  sshrc=1
  ssh-keygen -q -R $undercloudip > /dev/null 2>&1
  while [ $sshrc -ne 0 ]; do
    echo -n "."
    ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'uptime' > /dev/null
    sshrc=$?
    sleep 1
  done
  endlog "done"
  bash create_virsh_vms.sh
  startlog "Waiting for undercloud deployment"
  while [[ ! "$rc" =~ completed ]]; do
    echo -n "c"
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e stackrc ]; then echo completed; fi')
    printf "\b"
    echo -n "s"
    sleep 1
    printf "\b"
  done
  endlog "done"
  startlog "Waiting for overcloud deployment"
  rc=in_progress
  while [[ ! "$rc" =~ completed ]]; do
    echo -n "c"
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e cloud/overcloudrc ]; then echo completed; fi')
    printf "\b"
    echo -n "s"
    sleep 1
    printf "\b"
  done
  endlog "done"
else
  echo "Please run this on baremetal..."
fi
