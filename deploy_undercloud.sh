#!/bin/bash

source functions

source_rc setup.cfg

rc=255

function cleanup_logs {
  dirs="ceilometer heat glance horizon ironic ironic-discoverd keystone neutron nova swift"
  for dir in $dirs; do
    if [ -d "/var/log/$dir" ]; then
      sudo bash -c "rm -rf /var/log/$dir/*"
    fi
  done
}

function conformance {
  startlog "Updating system"
  sudo yum update -y 2>>$stderr 1>>$stdout
  endlog "done"
  startlog "Installing various packages"
  sudo yum install -y ntpdate ntp screen libguestfs-tools wget vim 2>>$stderr 1>>$stdout
  endlog "done"
  startlog "Synching time"
  sudo service ntpd stop 2>>$stderr 1>>$stdout
  sudo ntpdate $ntpserver 2>>$stderr 1>>$stdout
  sudo service ntpd start 2>>$stderr 1>>$stdout
  endlog "done"
}

function create_flavors {
  startlog "Creating flavors"
  run_in_qemu
  rc_qemu=$?
  if [ $rc_qemu -eq 0 ]; then
    if [[ $releasever =~ rhosp8 ]]; then
      ram=256
      disk=10
      vcpus=1
      swap=4096
      bram=256
    else
      ram=256
      disk=10
      vcpus=1
      swap=2048
      bram=256
    fi
  else
    ram=6144
    disk=40
    vcpus=4
    swap=0
    bram=4095
  fi
  for profile in swift-storage block-storage control ceph-storage compute; do
    openstack flavor delete $profile 2>>$stderr 1>>$stdout
    if [ $? -ne 0 ]; then
      nova flavor-delete $profile 2>>$stderr 1>>$stdout
    fi
    openstack flavor create --id auto --ram $ram --disk $disk --vcpus $vcpus --swap $swap $profile 2>>$stderr 1>>$stdout
    if [ $? -ne 0 ]; then
      nova flavor-create --swap $swap $profile auto $ram $disk $vcpus 2>>$stderr 1>>$stdout
    fi
    openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="$profile" --property "capabilities:boot_mode"="$boot_mode" $profile 2>>$stderr 1>>$stdout
    if [ $? -ne 0 ]; then
      nova flavor-key $profile set "cpu_arch"="x86_64" "capabilities:boot_option"="local" "capabilities:profile"="$profile" "capabilities:boot_mode"="$boot_mode"2>>$stderr 1>>$stdout
    fi
  done
  openstack flavor delete baremetal 2>>$stderr 1>>$stdout
  if [ $? -ne 0 ]; then
    nova flavor-delete baremetal 2>>$stderr 1>>$stdout
  fi
  openstack flavor create --id auto --ram $bram --disk $disk --vcpus $vcpus --swap $swap baremetal 2>>$stderr 1>>$stdout
  if [ $? -ne 0 ]; then
    nova flavor-create --swap $swap baremetal auto $bram $disk $vcpus 2>>$stderr 1>>$stdout
  fi
  endlog "done"
}

function tag_hosts {
  startlog "Tagging hosts"
  inc=0
  ironic node-list | grep -q manag
  if [ $? -eq 0 ]; then
    ironic node-list | grep mana | awk '{ print $2 }' | xargs -I% ironic node-set-provision-state % provide
  fi
  for p in $(ironic node-list | grep available | awk '{ print $2 }'); do
    if [ $inc -lt 3 -a $controlscale -eq 3 ] || [ $controlscale -eq 1 -a $inc -lt 1 ]; then
      ironic node-update $p add properties/capabilities="profile:control,boot_option:local,boot_mode:${boot_mode}" 2>>$stderr 1>>$stdout
    elif [ $inc -lt 6 -a $cephscale -gt 0 ]; then
      ironic node-update $p add properties/capabilities="profile:ceph-storage,boot_option:local,boot_mode:${boot_mode}" 2>>$stderr 1>>$stdout
    else
      ironic node-update $p add properties/capabilities="profile:compute,boot_option:local,boot_mode:${boot_mode}" 2>>$stderr 1>>$stdout
    fi
    inc=$( expr $inc + 1)
  done
  endlog "done"
}

function create_oc_images {
  startlog "Importing overcloud images"
  openstack overcloud image upload --image-path /home/stack/images 2>>$stderr 1>>$stdout
  endlog "done"
}

function baremetal_setup {
  startlog "Importing instackenv.json"
  openstack baremetal import --json /home/stack/instackenv.json 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
    startlog "Configure node boot"
    openstack baremetal configure boot 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
      startlog "Getting nodes information"
      ironic node-list 2>>$stderr 1>>$stdout
      ironic node-list | grep False | awk '{ print $2 }' | xargs -I% ironic node-show % 2>>$stderr 1>>$stdout
      endlog "done"
      startlog "Starting introspection"
      openstack baremetal introspection bulk start 2>>$stderr 1>>$stdout
      rc=$?
      if [ $rc -eq 0 ]; then
        endlog "done"
        if [ ! -d "/home/stack/deployment_state" ]; then
          mkdir -p /home/stack/deployment_state
        fi
        touch /home/stack/deployment_state/introspected
      else
        endlog "error"
      fi
    else
      endlog "error"
    fi
  else
    endlog "error"
  fi
  return $rc
}


function deploy_overcloud {
  rc=255
  if [ -d  "/home/stack/images" ]; then
    if [ -e "/home/stack/stackrc" ]; then
      create_oc_images
      baremetal_setup
      rc=$?
      if [ $rc -eq 0 ]; then
        create_flavors
        tag_hosts
        bash deploy_overcloud.sh
        rc=$?
      fi
    else 
      echo "Undercloud wasn't successfully deployed!"
    fi
  else
    echo "Please download the overcloud-* images and put them in /home/stack/images"
  fi
  return $rc
}

function install_undercloud {
  startlog "Installing undercloud"
  sudo yum install -y python-rdomanager-oscplugin openstack-utils 2>>$stderr 1>>$stdout
  openstack undercloud install 2>>$stderr 1>>$stdout
  rc=$?
  if [ $? -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
}

function disable_selinux {
  startlog "Disabling selinux"
  sudo /sbin/setenforce 0 2>>$stderr 1>>$stdout
  sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
  endlog "done"
}

function validate_network_environment {
  startlog "Validating network environment"
  git clone https://github.com/rthallisey/clapper 2>>$stderr 1>>$stdout
  python clapper/network-environment-validator.py -n ../$releasever/network-environment.yaml 2>>$stderr 1>>$stdout
  endlog "done"
  rc=$?
  return $rc
}

function delete_nova_nodes {
  for node in $(nova list | awk '{ print $2 }' | grep -v ID); do
    nova delete $node 2>>$stderr 1>>$stdout
  done
  if [ ! -z "$node" ]; then
    tnode=$(nova list | grep $node)
    while [[ "$tnode" =~ $node ]]; do
      tnode=$(nova list | grep $node)
      echo -n "."
    done
  fi
}
function poweroff_ironic_nodes {
  for node in $(ironic node-list | grep "power on" | awk '{ print $2 }'); do
    ironic node-set-power-state $node off 2>>$stderr 1>>$stdout
    tnode=$(ironic node-list | grep $node | grep "power on")
    while [[ "$tnode" =~ $node ]]; do
      tnode=$(ironic node-list | grep $node | grep "power on")
      echo -n "."
    done
  done
}
function delete_ironic_nodes {
  for node in $(ironic node-list | egrep "True|False" | awk '{ print $2 }'); do
    ironic node-delete $node 2>>$stderr 1>>$stdout
    tnode=$(ironic node-list | grep $node)
    while [[ "$tnode" =~ $node ]]; do
      tnode=$(ironic node-list | grep $node)
      echo -n "."
    done
  done
}
function delete_nodes {
  startlog "Deleting nodes"
  delete_nova_nodes
  poweroff_ironic_nodes
  delete_ironic_nodes
  endlog "done"
}

function create_overcloud_route {
  sudo ip addr add 10.1.2.1 dev br-ctlplane
  sudo route add -net 10.1.2.0 netmask 255.255.255.0 dev br-ctlplane
}

if [ -e "/home/stack/stackrc" ]; then
  source_rc /home/stack/stackrc
fi
conformance
install_undercloud
rc=$?
if [ $rc -eq 0 ]; then
  sudo crudini --set /etc/nova/nova.conf DEFAULT max_concurrent_builds 2
  sudo openstack-service restart nova
  enable_nfs
  disable_selinux
  source_rc /home/stack/stackrc
  validate_network_environment
  rc=$?
  if [ $rc -eq 0 ]; then
    create_overcloud_route
    deploy_overcloud
    rc=$?
    if [ $rc -eq 0 ]; then 
      test_overcloud
      rc=$?
      if [ $? -eq 0 ]; then
        touch /home/stack/deployment_state/tested
      fi
    fi
  fi
fi

exit $rc
