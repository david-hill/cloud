#!/bin/bash

source functions
source setup.cfg

function cleanup_logs {
  dirs="ceilometer heat glance horizon ironic ironic-discoverd keystone neutron nova swift"
  for dir in $dirs; do
    if [ -d "/var/log/$dir" ]; then
      sudo rm -rf "/var/log/$dir/*"
    fi
  done
}
function cleanup_undercloud {
  echo "Uninstalling undercloud..."
  rm overcloudrc
  sudo yum remove -y openstack-* python-oslo-* > /dev/null
  sudo yum remove -y mariadb > /dev/null
  sudo rm -rf /var/lib/mysql
  sudo rm -rf /var/lib/ironic-discoverd/discoverd.sqlite
  sudo yum install -y python-rdomanager-oscplugin > /dev/null
  cleanup_logs
}

function conformance {
  sudo yum update -y > /dev/null
  sudo yum install -y ntpdate ntp screen libguestfs-tools wget vim > /dev/null
  sudo service ntpd stop > /dev/null
  sudo ntpdate $ntpserver > /dev/null
  sudo service ntpd start > /dev/null
}

function create_flavors {
  echo "Creating flavors..."
  run_in_qemu
  rc_qemu=$?
  if [ $rc_qemu -eq 0 ]; then
    if [[ $releasever =~ rhosp8 ]]; then
      ram=1024
      disk=10
      vcpus=1
      swap=4096
      bram=1024
    else
      ram=1024
      disk=10
      vcpus=1
      swap=2048
      bram=1024
    fi
  else
    ram=6144
    disk=40
    vcpus=4
    swap=0
    bram=4095
  fi
  for profile in swift-storage block-storage control ceph-storage compute; do
    openstack flavor delete $profile > /dev/null
    openstack flavor create --id auto --ram $ram --disk $disk --vcpus $vcpus --swap $swap $profile > /dev/null
    openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="$profile" $profile > /dev/null
  done
  openstack flavor delete baremetal > /dev/null
  openstack flavor create --id auto --ram $bram --disk $disk --vcpus $vcpus --swap $swap baremetal > /dev/null
}

function tag_hosts {
  echo "Tagging hosts..."
  inc=0
  for p in $(ironic node-list | grep available | awk '{ print $2 }'); do
    if [ $inc -lt 3 -a $controlscale -eq 3 ] || [ $controlscale -eq 1 -a $inc -lt 1 ]; then
      ironic node-update $p add properties/capabilities='profile:control,boot_option:local' > /dev/null
    elif [ $inc -lt 6 -a $cephscale -gt 0 ]; then
      ironic node-update $p add properties/capabilities='profile:ceph-storage,boot_option:local' > /dev/null
    else
      ironic node-update $p add properties/capabilities='profile:compute,boot_option:local' > /dev/null
    fi
    inc=$( expr $inc + 1)
  done
}

function create_oc_images {
  echo "Importing overcloud images..."
  openstack overcloud image upload --image-path /home/stack/images > /dev/null
}

function baremetal_setup {
  echo "Configure baremetal hosts..."
  echo "Importing instackenv.json..."
  openstack baremetal import --json /home/stack/instackenv.json > /dev/null
  echo "Configure node boot..."
  openstack baremetal configure boot > /dev/null
  echo "Starting introspection..."
  openstack baremetal introspection bulk start > /dev/null
}


function deploy_overcloud {
  echo "Deploying overcloud ..."
  if [ -d  "/home/stack/images" ]; then
    if [ -e "/home/stack/stackrc" ]; then
      create_oc_images
      baremetal_setup
      create_flavors
      tag_hosts
      bash deploy_overcloud.sh
      if [ $? -ne 0 ]; then
        exit 255
      fi
    else 
      echo "Undercloud wasn't successfully deployed!"
    fi
  else
    echo "Please download the overcloud-* images and put them in /home/stack/images"
  fi
}

function install_undercloud {
  echo "Installing undercloud ..."
  openstack undercloud install > /dev/null
}

function validate_network_environment {
  echo "Validating network environment..."
  git clone https://github.com/rthallisey/clapper > /dev/null
  python clapper/network-environment-validator.py -n ../$releasever/network-environment.yaml > /dev/null
  rc=$?
  return $rc
}

function delete_nova_nodes {
  echo "Deleting nova nodes.."
  for node in $(nova list | awk '{ print $2 }' | grep -v ID); do
    nova delete $node > /dev/null
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
  echo "Powering off ironic nodes.."
  for node in $(ironic node-list | grep "power on" | awk '{ print $2 }'); do
    ironic node-set-power-state $node off > /dev/null
    tnode=$(ironic node-list | grep $node | grep "power on")
    while [[ "$tnode" =~ $node ]]; do
      tnode=$(ironic node-list | grep $node | grep "power on")
      echo -n "."
    done
  done
}
function delete_ironic_nodes {
  echo "Deleting ironic nodes.."
  for node in $(ironic node-list | egrep "True|False" | awk '{ print $2 }'); do
    ironic node-delete $node > /dev/null
    tnode=$(ironic node-list | grep $node)
    while [[ "$tnode" =~ $node ]]; do
      tnode=$(ironic node-list | grep $node)
      echo -n "."
    done
  done
}
function delete_nodes {
  echo "Deleting nodes..."
  delete_nova_nodes
  poweroff_ironic_nodes
  delete_ironic_nodes
}

function create_overcloud_route {
  sudo ip addr add 10.1.2.1 dev br-ctlplane
  sudo route add -net 10.1.2.0 netmask 255.255.255.0 dev br-ctlplane
}

delete_overcloud
delete_nodes
cleanup_undercloud
conformance
install_undercloud
source_rc /home/stack/stackrc
validate_network_environment
if [ $? -eq 0 ]; then
  create_overcloud_route
  deploy_overcloud
  test_overcloud
else
  exit 255
fi
