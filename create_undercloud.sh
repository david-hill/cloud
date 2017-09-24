#!/bin/bash

source functions
source_rc setup.cfg

echo 2>$stderr 1>$stdout

if [ ! -z $1 ]; then
  installtype=$1
fi

if [ ! -z $2 ]; then
  rdorelease=$2
fi

if [ ! -z $3 ]; then
  branchtype=$3;
fi

validate_rpm libguestfs-tools

if [ -e /etc/redhat-release ]; then
  grep -qi "Fedora" /etc/redhat-release
  if [ $? -eq 0 ]; then
    uploadcmd="--copy-in"
  else
    uploadcmd="--upload"
  fi
else
  uploadcmd="--copy-in"
fi

function wait_for_image_generation {
  startlog "Waiting for image generation"
  rc=in_progress
  while [[ ! "$rc" =~ completed ]] && [[ ! "$rcf" =~ failed ]]; do
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e gen_images_completed ]; then echo completed; fi')
    rcf=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e failed ]; then echo failed; fi')
    sleep 1
  done
  if [[ ! "$rcf" =~ failed ]]; then
    endlog "done"
    rc=0
  else
    endlog "error"
    rc=255
  fi
  return $rc
}

function generate_images {
  rc=0
  cd images
  bash verify_repo.sh $rdorelease
  if [ $? -eq 0 ]; then
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'touch gen_images')
    cd ..
    wait_for_image_generation
    rc=$?
    if [ $rc -eq 0 ]; then
      fetch_images
      rc=$?
    fi
  else
    cd ..
  fi
  return $rc
}

function upload_rhel_image {
  startlog "Uploading RHEL image"
  ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip 'if [ ! -e images ]; then mkdir images; fi' > /dev/null
  scp -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no tmp/rhel-guest-image-local.qcow2 stack@$undercloudip:images/ 2>>$stderr 1>>$stdout
  endlog "done"
}
function customize_rhel_image {
  startlog "Customizing RHEL image"
  rhelimage=$(ls -atr images/rhel/ | grep qcow2 | grep $rhel | tail -1)
  sudo cp images/rhel/$rhelimage tmp/rhel-guest-image-local.qcow2
  sudo chown qemu tmp/rhel-guest-image-local.qcow2
  sudo virt-customize -v -a tmp/rhel-guest-image-local.qcow2 $uploadcmd iptables:/etc/sysconfig/ 2>>$stderr 1>>$stdout
  endlog "done"
}
function get_new_images {
  rc=0
  diff=0
  continue=1
  startlog "Getting new images"
  while [ $continue -eq 1 ]; do
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip "if [ -e rhosp-director-images.latest ]; then echo present; fi")
    rcf=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip "if [ -e rhosp-director-images.missing ]; then echo missing; fi")
    if [[ $rc =~ present ]] || [[ $rcf =~ missing ]]; then
      continue=0
    fi
  done
  if [[ $rc =~ present ]]; then
    rc=0
    scp -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip:rhosp-director-images.latest images/$releasever/${minorver}/ 2>>$stderr 1>>$stdout
    if [ ! -e images/$releasever/${minorver}/rhosp-director-images.previous ]; then
      diff=1
      if [ -e images/$releasever/${minorver}/version ]; then
        backupfolder=$(cat images/$releasever/${minorver}/version)
      else
        backupfolder=$( date +'%Y%m%d%H' )
      fi
    else
      cmp -s images/$releasever/${minorver}/rhosp-director-images.previous images/$releasever/${minorver}/rhosp-director-images.latest
      if [ $? -ne 0 ]; then
        diff=1
      fi
      if [ $diff -eq 1 ]; then
        backupfolder=$(cat images/$releasever/${minorver}/rhosp-director-images.previous)
      fi
    fi
    if [ $diff -eq 1 ]; then
      mkdir -p images/$releasever/${minorver}/backup/${backupfolder}
      mv images/$releasever/${minorver}/*.tar images/$releasever/${minorver}/backup/${backupfolder}
      scp -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip:/usr/share/rhosp-director-images/ironic-python-agent.tar images/$releasever/${minorver}/ 2>>$stderr 1>>$stdout
      scp -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@$undercloudip:/usr/share/rhosp-director-images/overcloud-full.tar images/$releasever/${minorver}/ 2>>$stderr 1>>$stdout
      if [ -e images/$releasever/${minorver}/rhosp-director-images.latest ]; then
        cat images/$releasever/${minorver}/rhosp-director-images.latest > images/$releasever/${minorver}/rhosp-director-images.previous
      fi
    fi
  else
    rc=255
  fi
  endlog "done"
  return $rc
}
function kill_dnsmasq {
    rc=1
    pgrep dnsmasq 2>>$stderr 1>>$stdout
    if [ $? -eq 0 ]; then
      sudo pkill dnsmasq
      rc=$?
    fi
    return $rc
}
function wait_for_dnsmasq {
    rc=1
    ttimeout=10
    while [ $rc -eq 1 ] && [ $ttimeout -gt 0 ]; do
      pgrep dnsmasq 2>>$stderr 1>>$stdout
      rc=$?
      ttimeout=`expr $ttimeout - 1`
      sleep 1
    done
    return $rc
}

function restart_libvirtd {
  sudo systemctl restart libvirtd
  return $?
}

function spawn_undercloud_vm {
      tmpfile=$(mktemp)
      uuid=$(uuidgen)
      tpath=$jenkinspath/VMs
      vcpus=4
      gen_macs
      gen_xml
      create_domain
      start_domain
      cleanup
}

function wait_for_undercloud_deployment {
  startlog "Waiting for undercloud deployment"
  rc=0
  while [[ ! "$rc" =~ completed ]] && [[ ! "$rcf" =~ failed ]]; do
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e stackrc ]; then echo completed; fi')
    rcf=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e failed ]; then echo failed; fi')
    sleep 1
  done
  if [[ ! "$rcf" =~ failed ]]; then
    endlog "done"
    rc=0
  else
    endlog "error"
    rc=255
  fi
  return $rc
}

function fetch_images {
  cd images/rdo-$rdorelease
  startlog "Fetch images"
  scp -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@192.168.122.2:images/*.tar .
  if [ $? -eq 0 ]; then
    endlog "done"
    rc=0
  else
    endlog "error"
    rc=255
  fi
  cd ../../
  return $rc
}

function wait_for_introspection {
  startlog "Waiting for introspection"
  rc=in_progress
  while [[ ! "$rc" =~ completed ]] && [[ ! "$rcf" =~ failed ]]; do
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e deployment_state/introspected ]; then echo completed; fi')
    rcf=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e failed ]; then echo failed; fi')
    sleep 1
  done
  if [[ ! "$rcf" =~ failed ]]; then
    endlog "done"
    rc=0
  else
    endlog "error"
    rc=255
  fi
  return $rc
}
function wait_for_vm {
  tinitial=$(date "+%s")
  telapsed=0
  startlog "Waiting for VM to come up"
  down=1
  while [ $down -eq 1 ] && [ $telapsed -lt $timeout ]; do
    ping -q -c 1 $undercloudip 2>>$stderr 1>>$stdout
    tcurrent=$(date "+%s")
    telapsed=$(( $tcurrent - $initial ))
    down=$?
    sleep 1
  done
  if [ $telapsed -lt $timeout ]; then
    endlog "done"
    rc=0
  else
    endlog "error"
    rc=255
  fi
  return $rc
}

function wait_for_overcloud_test {
  startlog "Waiting for overcloud test"
  rc=in_progress
  while [[ ! "$rc" =~ completed ]] && [[ ! "$rcf" =~ failed ]]; do
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e deployment_state/tested ]; then echo completed; fi')
    rcf=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e failed ]; then echo failed; fi')
    sleep 1
  done
  if [[ ! "$rcf" =~ failed ]]; then
    endlog "done"
    rc=0
  else
    endlog "error"
    rc=255
  fi
  return $rc
}

function copy_image {
  startlog "Copying base image"
  image=$(ls -1 images/rhel | grep qcow2 | grep $rhel | tail -1)
  sudo cp images/rhel/${image} $jenkinspath/VMs/${vmname}.qcow2
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
}

function resize_base_disk {
  startlog "Resizing base disk"
  sudo qemu-img resize $jenkinspath/VMs/${vmname}.qcow2 30G 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
}

function create_base_image {
  copy_image
  rc=$?
  if [ $rc -eq 0 ]; then
    resize_base_disk
    rc=$?
  fi
  return $rc
}

function flush_arp_table {
  for arpentry in $( sudo arp -na | grep virbr | awk '{ print $2 }' | sed -e 's/(//g' -e 's/)//g' ); do
    sudo arp -i virbr0 -d $arpentry
  done
}

function wait_for_ssh {
  startlog "Waiting for SSH to come up"
  sshrc=1
  tinitial=$(date "+%s")
  telapsed=0
  ssh-keygen -q -R $undercloudip 2>>$stderr 1>>$stdout
  while [ $sshrc -ne 0 ] && [ $telapsed -lt $timeout ]; do
    ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'uptime' 2>>$stderr 1>>$stdout
    tcurrent=$(date "+%s")
    telapsed=$(( $tcurrent - $initial ))
    sshrc=$?
    sleep 1
  done
  if [ $telapsed -lt $timeout ]; then
    endlog "done"
    rc=0
  else
    endlog "error"
    rc=255
  fi
  return $rc
}

function fetch_internal_images {
  if [[ "$installtype" =~ internal ]]; then
    if [ -e images/rhel/get_image.sh ]; then
      startlog "Fetching image"
      cd images/rhel
      bash get_image.sh
      cd ../../
      endlog "done"
    fi
    if [ -e images/$releasever/${minorver}/update_images.sh ]; then
      startlog "Fetching RHOSP image"
      cd images/$releasever/${minorver}/
      bash update_images.sh
      cd ../../../  
      endlog "done"
    fi
  fi
}

function wait_for_overcloud_deployment {
  startlog "Waiting for overcloud deployment"
  rc=in_progress
  while [[ ! "$rc" =~ completed ]] && [[ ! "$rcf" =~ failed ]]; do
    rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e cloud/overcloudrc ]; then echo completed; fi')
    rcf=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e failed ]; then echo failed; fi')
    sleep 1
  done
  if [[ ! "$rcf" =~ failed ]]; then
    endlog "done"
    rc=0
  else
    endlog "error"
    rc=255
  fi
  return $rc
}
function customize_image {
  startlog "Customizing image"
  sed -i "s/###MINORVER###/$minorver/g" tmp/S01customize
  sed -i "s/###RELEASEVER###/$releasever/g" tmp/S01customize
  sed -i "s/###INSTALLTYPE###/$installtype/g" tmp/S01customize
  sed -i "s/###RDORELEASE###/$rdorelease/g" tmp/S01customize
  sed -i "s/###BRANCHTYPE###/$branchtype/g" tmp/S01customize
  sed -i "s/###ENABLENFS###/$enablenfs/g" tmp/S01customize
  sed -i "s/###EMAIL###/$email/g" tmp/S01customize
  sed -i "s/###RHNUSERNAME###/$rhnusername/g" tmp/S01customize
  sed -i "s/###RHNPASSWORD###/$rhnpassord/g" tmp/S01customize
  sed -i "s/###FULLNAME###/$fullname/g" tmp/S01customize
  echo sudo virt-customize -v -a $jenkinspath/VMs/${vmname}.qcow2 $uploadcmd iptables:/etc/sysconfig/ $uploadcmd customize.service:/etc/systemd/system/ $uploadcmd tmp/S01customize:/etc/rc.d/rc3.d/ $uploadcmd S01loader:/etc/rc.d/rc3.d/ --root-password password:$rootpasswd --link /etc/systemd/system/customize.service:/etc/systemd/system/multi-user.target.wants/customize.service $uploadcmd cloud.cfg:/etc/cloud 2>>$stderr 1>>$stdout
  sudo virt-customize -v -a $jenkinspath/VMs/${vmname}.qcow2 $uploadcmd iptables:/etc/sysconfig/ $uploadcmd customize.service:/etc/systemd/system/ $uploadcmd tmp/S01customize:/etc/rc.d/rc3.d/ $uploadcmd S01loader:/etc/rc.d/rc3.d/ --root-password password:$rootpasswd --link /etc/systemd/system/customize.service:/etc/systemd/system/multi-user.target.wants/customize.service $uploadcmd cloud.cfg:/etc/cloud 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
    rc=0
  else
    endlog "error"
    rc=255
  fi
  return $rc
}

function stop_vm_if_running {
  ping -c1 192.168.122.2 2>>$stderr 1>>$stdout
  if [ $? -eq 0 ]; then
    bash stop_vms.sh
  fi
}

function prepare_hypervisor {
  echo > /dev/null
#      sudo ip addr show dev virbr0 2>>$stderr| grep -q "169.254.169.254"
#      if [ $? -eq 1 ]; then
#        sudo ip addr add 169.254.169.254/32 dev virbr0 2>>$stderr 1>>$stdout
#      fi
#      sudo iptables -nL INPUT_direct -v | grep virbr0 | grep -v tun0 | grep -q dpt:80
#      if [ $? -eq 1 ]; then
#        sudo iptables -I INPUT_direct -m tcp -p tcp -i virbr0 --dport 80 -j ACCEPT 2>>$stderr 1>>$stdout
#      fi
}

function vpn_setup {
  rc=255
  vpnip=$(ip addr | grep "inet 10\." | awk ' { print $2 }' | sed -e 's#/.*##')
  if [ ! -z "${vpnip}" ]; then
    sudo iptables -t nat -nL POSTROUTING -v | grep 10.0.0.0 | grep -q $vpnip
    rc=$?
    if [ $rc -ne 0 ]; then
      sudo iptables -t nat -I POSTROUTING -s 192.168.122.0/24 -d 10.0.0.0/8 -o eno1 -j SNAT --to-source $vpnip 2>>$stderr 1>>$stdout
      rc=$?
    fi
  fi
  return $rc
}

validate_env
if [ ! -d tmp ]; then
  mkdir tmp
fi

stop_vm_if_running

rc=0
if [ $rc -eq 0 ]; then
  rc=0
  if [ $rc -eq 0 ]; then
    memory=$undercloudmemory
    type=undercloud
    inc=0
    if [[ $installtype =~ rdo ]]; then
      vmname="${type}-${inc}-${rdorelease}"
    else
      vmname="${type}-${inc}-${releasever}"
    fi
    if [ -e "S01customize.local" ]; then
      cp S01customize.local tmp/S01customize
    else    
      cp S01customize tmp/S01customize
    fi
    restart_libvirtd
    wait_for_dnsmasq
    rc=$?
    if [ $? -eq 0 ]; then
      kill_dnsmasq
      rc=0
    else
      rc=0
    fi
    if [ $rc -eq 0 ]; then
    #  sed -i "s/rhosp8/$releasever/g" tmp/S01customize
      if [ ! -d $jenkinspath/VMs ]; then
        mkdir -p $jenkinspath/VMs
      fi
      prepare_hypervisor
      flush_arp_table
      vpn_setup
      if [ $? -eq 0 ]; then
        fetch_internal_images
      else
        echo "WARNING: No VPN IP found..."
      fi
      create_base_image
      rc=$?
      if [ $rc -eq 0 ]; then
        customize_image
        rc=$?
        if [ $rc -eq 0 ]; then
          spawn_undercloud_vm
          wait_for_vm
          rc=$?
          if [ $rc -eq 0 ]; then
            wait_for_ssh
            rc=$?
            if [ $rc -eq 0 ]; then
              if [ ! -z $rdorelease ]; then
                wait_for_reboot
                if [ $? -eq 0 ]; then
                  customize_rhel_image
                  upload_rhel_image
                  generate_images
                  rc=$?
                else
                  endlog "error"
                fi
              fi
              if [ $rc -eq 0 ]; then
                bash create_virsh_vms.sh $installtype $rdorelease
                rc=$?
                if [ $rc -eq 0 ]; then
                  wait_for_undercloud_deployment
                  rc=$?
                  if [ $rc -eq 0 ]; then
                    if [ -z $rdorelease ]; then
                      get_new_images
                    fi
                    wait_for_introspection
                    rc=$?
                    if [ $rc -eq 0 ]; then
                      wait_for_overcloud_deployment
                      rc=$?
                      if [ $rc -eq 0 ]; then
                        wait_for_overcloud_test
                        rc=$?
                      fi
                    fi
                  fi
                fi
              fi
            fi
          fi
        fi
      fi
    fi
  fi
fi

exit $rc
