#!/bin/bash

source functions
source_rc setup.cfg

if [ ! -z $1 ]; then
  installtype=$1
fi

validate_env
if [ ! -d tmp ]; then
  mkdir tmp
fi

if [ -e images/$releasever/${minorver}/update_images.sh ]; then
  cd images/$releasever/${minorver}/
  bash update_images.sh
  rc=$?
  cd ../../../  
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
#  sed -i "s/rhosp8/$releasever/g" tmp/S01customize
  mkdir /home/jenkins/VMs
  vpnip=$(ip addr | grep inet | grep 10 | awk ' { print $2 }' | sed -e 's#/.*##')
  sudo iptables -t nat -I POSTROUTING -s 192.168.122.0/24 -d 10.0.0.0/8 -o wlp3s0 -j SNAT --to-source $vpnip
  startlog "Copying base image"
  sudo cp /home/jenkins/cloud/images/rhel/rhel-guest-image-7.2-20160302.0.x86_64.qcow2 /home/jenkins/VMs/${vmname}.qcow2
  endlog "done"
  startlog "Resizing base disk"
  sudo qemu-img resize /home/jenkins/VMs/${vmname}.qcow2 30G 2>$stderr 1>$stdout
  endlog "done"
  startlog "Customizing image"
  sed -i "s/###MINORVER###/$minorver/g" tmp/S01customize
  sed -i "s/###RELEASEVER###/$releasever/g" tmp/S01customize
  sed -i "s/###INSTALLTYPE###/$installtype/g" tmp/S01customize
  sudo virt-customize -a /home/jenkins/VMs${vmname}.qcow2 --copy-in customize.service:/etc/systemd/system/ --copy-in tmp/S01customize:/etc/rc.d/rc3.d/ --copy-in S01loader:/etc/rc.d/rc3.d/ --root-password password:$rootpasswd --link /etc/systemd/system/customize.service:/etc/systemd/system/multi-user.target.wants/customize.service --copy-in cloud.cfg:/etc/cloud 2>$stderr 1>$stdout
  endlog "done"

  tmpfile=$(mktemp)
  uuid=$(uuidgen)
  tpath='/home/jenkins/VMs'
  vcpus=2
  gen_macs
  gen_xml
  create_domain
  start_domain
  cleanup

  startlog "Waiting for VM to come up"
  down=1
  while [ $down -eq 1 ]; do
    ping -q -c 1 $undercloudip 2>$stderr 1>$stdout
    down=$?
    sleep 1
  done
  endlog "done"
  startlog "Waiting for SSH to come up"
  sshrc=1
  ssh-keygen -q -R $undercloudip 2>$stderr 1>$stdout
  while [ $sshrc -ne 0 ]; do
    ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'uptime' 2>$stderr 1>$stdout
    sshrc=$?
    sleep 1
  done
  endlog "done"
  bash create_virsh_vms.sh
  startlog "Waiting for undercloud deployment"
  while [[ ! "$rc" =~ completed ]]; do
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e stackrc ]; then echo completed; fi')
    sleep 1
  done
  endlog "done"
  startlog "Waiting for introspection"
  rc=in_progress
  while [[ ! "$rc" =~ completed ]]; do
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e deployment_state/introspected ]; then echo completed; fi')
    sleep 1
  done
  endlog "done"
  startlog "Waiting for overcloud deployment"
  rc=in_progress
  while [[ ! "$rc" =~ completed ]]; do
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e cloud/overcloudrc ]; then echo completed; fi')
    sleep 1
  done
  endlog "done"
  startlog "Waiting for overcloud test"
  rc=in_progress
  while [[ ! "$rc" =~ completed ]]; do
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e deployment_state/tested ]; then echo completed; fi')
    sleep 1
  done
  endlog "done"
else
  echo "Please run this on baremetal..."
fi
