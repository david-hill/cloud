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
  sudo yum install -y ntpdate ntp screen
  sudo service ntpd stop
  sudo ntpdate $ntpserver
  sudo service ntpd start
}

function create_flavors {
  echo "Creating flavors..."
  for profile in control compute ceph-storage; do
    openstack flavor create --id auto --ram 6144 --disk 40 --vcpus 4 $profile
    openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="$profile" $profile
  done

  openstack flavor create --id auto --ram 4096 --disk 40 --vcpus 4 baremetal
}

function tag_hosts {
  echo "Tagging hosts..."
  inc=0
  for p in $(ironic node-list | grep available | awk '{ print $2 }'); do
    if [ $inc -lt 3 ]; then
      ironic node-update $p add properties/capabilities='profile:control,boot_option:local'
    elif [ $inc -lt 6 ]; then
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
  openstack baremetal import --json /home/stack/instackenv.json
  openstack baremetal configure boot
  openstack baremetal introspection bulk start
}


function deploy_overcloud {
  echo "Deploying overcloud ..."
  if [ -d  "/home/stack/images" ]; then
    if [ -e "~/stackrc" ]; then
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
  python clapper/network-environment-validator.py
}

delete_overcloud
cleanup_undercloud
conformance
install_undercloud
validate_network_environment
deploy_overcloud
test_overcloud
