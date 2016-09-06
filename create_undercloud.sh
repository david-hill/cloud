#!/bin/bash

source functions
source_rc setup.cfg

if [ ! -z $1 ]; then
  installtype=$1
fi

if [ ! -z $2 ]; then
  rdorelease=$2
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


validate_env
if [ ! -d tmp ]; then
  mkdir tmp
fi

rc=0
if [ -e images/$releasever/${minorver}/update_images.sh ]; then
  cd images/$releasever/${minorver}/
  bash update_images.sh
  rc=$?
  cd ../../../  
fi

if [ $rc -eq 0 ]; then
  if [ -e images/rhel/get_image.sh ]; then
    cd images/rhel
    bash get_image.sh
    rc=$?
    cd ../../
  fi
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
    sudo pkill dnsmasq
  #  sed -i "s/rhosp8/$releasever/g" tmp/S01customize
    if [ ! -d /home/jenkins/VMs ]; then
      mkdir -p /home/jenkins/VMs
    fi
    vpnip=$(ip addr | grep inet | grep "10\." | awk ' { print $2 }' | sed -e 's#/.*##')
    if [ ! -z "${vpnip}" ]; then
      sudo iptables -t nat -I POSTROUTING -s 192.168.122.0/24 -d 10.0.0.0/8 -o wlp3s0 -j SNAT --to-source $vpnip
    else
      echo "WARNING: No VPN IP found..."
    fi
    startlog "Copying base image"
    sudo cp /home/jenkins/cloud/images/rhel/rhel-guest-image-7.2-20160302.0.x86_64.qcow2 /home/jenkins/VMs/${vmname}.qcow2
    if [ $? -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
      exit 2
    fi
    startlog "Resizing base disk"
    sudo qemu-img resize /home/jenkins/VMs/${vmname}.qcow2 30G 2>$stderr 1>$stdout
    if [ $? -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
      exit 2
    fi
    startlog "Customizing image"
    sed -i "s/###MINORVER###/$minorver/g" tmp/S01customize
    sed -i "s/###RELEASEVER###/$releasever/g" tmp/S01customize
    sed -i "s/###INSTALLTYPE###/$installtype/g" tmp/S01customize
    sed -i "s/###RDORELEASE###/$rdorelease/g" tmp/S01customize
    sudo virt-customize -a /home/jenkins/VMs/${vmname}.qcow2 $uploadcmd customize.service:/etc/systemd/system/ $uploadcmd tmp/S01customize:/etc/rc.d/rc3.d/ $uploadcmd S01loader:/etc/rc.d/rc3.d/ --root-password password:$rootpasswd --link /etc/systemd/system/customize.service:/etc/systemd/system/multi-user.target.wants/customize.service $uploadcmd cloud.cfg:/etc/cloud 2>$stderr 1>$stdout
    if [ $? -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
      exit 2
    fi

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
    if [ ! -z $rdorelease ]; then
      cd images
      bash verify_repo.sh $rdorelease
      if [ $? -eq 0 ]; then
        rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'touch gen_images')
      fi
      cd ..
      startlog "Waiting for image generation"
      rc=0
      while [[ ! "$rc" =~ completed ]] && [[ ! "$rcf" =~ failed ]]; do
        rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e gen_images_completed ]; then echo completed; fi')
        rcf=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e failed ]; then echo failed; fi')
        sleep 1
      done
      if [[ ! "$rcf" =~ failed ]]; then
        endlog "done"
        cd images/rdo-$rdorelease
        startlog "Fetch images"
        scp -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no stack@192.168.122.2:images/*.tar .
        if [ $? -eq 0 ]; then
          endlog "done"
        else
          endlog "error"
        fi
        cd ../../
      else
        endlog "error"
      fi
    fi
    if [[ ! "$rcf" =~ failed ]]; then
      bash create_virsh_vms.sh $installtype $rdorelease
      startlog "Waiting for undercloud deployment"
      rc=0
      while [[ ! "$rc" =~ completed ]] && [[ ! "$rcf" =~ failed ]]; do
        rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e stackrc ]; then echo completed; fi')
        rcf=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e failed ]; then echo failed; fi')
        sleep 1
      done
    fi
    if [[ ! "$rcf" =~ failed ]]; then
      endlog "done"
      startlog "Waiting for introspection"
      rc=in_progress
      while [[ ! "$rc" =~ completed ]] && [[ ! "$rcf" =~ failed ]]; do
        rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e deployment_state/introspected ]; then echo completed; fi')
        rcf=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e failed ]; then echo failed; fi')
        sleep 1
      done
      if [[ ! "$rcf" =~ failed ]]; then
        endlog "done"
        startlog "Waiting for overcloud deployment"
        rc=in_progress
        while [[ ! "$rc" =~ completed ]] && [[ ! "$rcf" =~ failed ]]; do
          rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e cloud/overcloudrc ]; then echo completed; fi')
          rcf=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e failed ]; then echo failed; fi')
          sleep 1
        done
        if [[ ! "$rcf" =~ failed ]]; then
          endlog "done"
          startlog "Waiting for overcloud test"
          rc=in_progress
          while [[ ! "$rc" =~ completed ]] && [[ ! "$rcf" =~ failed ]]; do
            rc=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e deployment_state/tested ]; then echo completed; fi')
            rcf=$(ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$undercloudip 'if [ -e failed ]; then echo failed; fi')
            sleep 1
          done
          if [[ ! "$rcf" =~ failed ]]; then
            endlog "done"
          fi
        else
          endlog "error"
        fi
      else
        endlog "error"
      fi
    else
      endlog "error"
    fi
    if [[ $rc =~ completed ]]; then
      endlog "done"
      rc=0
    else
      rc=255
      endlog "error"
    fi
  fi
else
  echo "Please run this on baremetal..."
  rc=1
fi
exit $rc
