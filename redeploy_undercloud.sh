#!/bin/bash

source functions

function cleanup_undercloud {
  echo "Uninstalling undercloud..."
  rm overcloudrc
  sudo yum remove -y openstack-* python-oslo-*
  sudo yum remove -y mariadb
  sudo rm -rf /var/lib/mysql
  sudo yum install -y python-rdomanager-oscplugin
  sudo echo >/var/log/heat/heat-engine.log
}

function conformance {
  sudo yum update -y
  sudo yum install -y ntpdate ntp screen libguestfs-tools
  sudo service ntpd stop
  sudo ntpdate $ntpserver
  sudo service ntpd start
}

function create_flavors {
  echo "Creating flavors..."
  if [ -z "$kvmhost" ]; then
    ram=1024
    disk=10
    vcpus=1
    swap=2048
    bram=1024
  else
    ram=6144
    disk=40
    vcpus=4
    swap=0
    bram=4095
  fi
  for profile in control compute ceph-storage; do
    openstack flavor create --id auto --ram $ram --disk $disk --vcpus $vcpus --swap $swap $profile
    openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="$profile" $profile
  done

  openstack flavor create --id auto --ram $bram --disk $disk --vcpus $vcpus --swap $swap baremetal
}

function tag_hosts {
  echo "Tagging hosts..."
  inc=0
  for p in $(ironic node-list | grep available | awk '{ print $2 }'); do
    if [ $inc -lt 3 ]; then
      ironic node-update $p add properties/capabilities='profile:control,boot_option:local'
    elif [ $inc -lt 6 -a $cephscale -gt 0 ]; then
      ironic node-update $p add properties/capabilities='profile:cep-storage,boot_option:local'
    else
      ironic node-update $p add properties/capabilities='profile:compute,boot_option:local'
    fi
    inc=$( expr $inc + 1)
  done
}

function create_oc_images {
  echo "Importing overcloud images..."
  openstack overcloud image upload --image-path /home/stack/images
}

function baremetal_setup {
  echo "Configure baremetal hosts..."
  echo "Importing instackenv.json..."
  openstack baremetal import --json /home/stack/instackenv.json
  echo "Configure node boot..."
  openstack baremetal configure boot
  echo "Starting introspection..."
  openstack baremetal introspection bulk start
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
  openstack undercloud install
}

function validate_network_environment {
  echo "Validating network environment..."
  git clone https://github.com/rthallisey/clapper
  python clapper/network-environment-validator.py -n ../templates/network-environment.yaml
  rc=$?
  return $rc
}

function delete_nova_nodes {
  echo "Deleting nova nodes.."
  for node in $(nova list | awk '{ print $2 }' | grep -v ID); do
    nova delete $node
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
    ironic node-set-power-state $node off
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
    ironic node-delete $node
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

delete_overcloud
delete_nodes
cleanup_undercloud
conformance
install_undercloud
validate_network_environment
if [ $? -eq 0 ]; then
  deploy_overcloud
  test_overcloud
else
  exit 255
fi
