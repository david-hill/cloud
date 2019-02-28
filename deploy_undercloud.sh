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
  rc=0
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
  return $rc
}

function tag_hosts {
  rc=0
  startlog "Tagging hosts"
  inc=0
  ironic node-list 2>>$stderr | grep -q manag
  if [ $? -eq 0 ]; then
    ironic node-list 2>>$stderr | grep mana | awk '{ print $2 }' | xargs -I% ironic node-set-provision-state % provide
  fi
  openstack overcloud profiles list 2>>$stderr 1>>$stdout
  ironic node-list 2>>$stderr 1>>$stdout
  if [ $? -eq 0 ]; then
    output=$(ironic node-list 2>>$stderr | grep available | awk '{ print $2 }')
  else
    output=$(openstack overcloud profiles list 2>>$stderr | grep available | awk '{ print $2 }')
  fi
  for p in $output; do
    if [ $inc -lt 3 -a $controlscale -eq 3 ] || [ $controlscale -eq 1 -a $inc -lt 1 ]; then
      ironic node-update $p add properties/capabilities="profile:control,boot_option:local,boot_mode:${boot_mode}" 2>>$stderr 1>>$stdout
      if [ $? -ne 0 ]; then
        openstack baremetal node set --property capabilities="profile:control,boot_option:local,boot_mode:${boot_mode}" $p 2>>$stderr 1>>$stdout
      fi
    elif [ $inc -lt 6 -a $cephscale -gt 0 ]; then
      ironic node-update $p add properties/capabilities="profile:ceph-storage,boot_option:local,boot_mode:${boot_mode}" 2>>$stderr 1>>$stdout
      if [ $? -ne 0 ]; then
        openstack baremetal node set --property capabilities="profile:ceph-storage,boot_option:local,boot_mode:${boot_mode}" $p 2>>$stderr 1>>$stdout
      fi
    else
      ironic node-update $p add properties/capabilities="profile:compute,boot_option:local,boot_mode:${boot_mode}" 2>>$stderr 1>>$stdout
      if [ $? -ne 0 ]; then
        openstack baremetal node set --property capabilities="profile:compute,boot_option:local,boot_mode:${boot_mode}" $p 2>>$stderr 1>>$stdout
      fi
    fi
    inc=$( expr $inc + 1)
  done
  if [ $inc -eq 0 ]; then
    endlog "error"
    rc=1
  else
    endlog "done"
  fi
  return $rc
}


function get_oc_images {
  if [ ! -d /home/stack/images ]; then
    mkdir -p /home/stack/images
  fi
  diff=0
  ver=$(sudo yum info rhosp-director-images 2>>$stderr | grep Release | awk '{ print $3 }')
  if [ ! -z "$ver" ]; then
    echo "$ver" > ../rhosp-director-images.current
    if [ -e ../rhosp-director-images.previous ]; then
      cmp -s ../rhosp-director-images.previous ../rhosp-director-images.current
      if [ $? -ne 0 ]; then
        diff=1
      fi
    else
      diff=1
    fi
  fi
  if [ $diff -eq 1 ]; then
    startlog "Installing images RPMs"
    sudo yum install -y rhosp-director-images rhosp-director-images-ipa 2>>$stderr 1>>$stdout
    rc=0
    if [ $rc -eq 0 ]; then
      endlog "done"
      startlog "Extracting images"
      for tarfile in /usr/share/rhosp-director-images/*.tar; do tar -xf $tarfile -C ~/images; done
      endlog "done"
    else
      endlog "error"
    fi
  fi
  if [ ! -z "$ver" ]; then
    echo "$ver" > ../rhosp-director-images.latest
  else
    touch ../rhosp-director-images.missing
    rc=0
  fi
  return $rc
}
function upload_oc_images {
  startlog "Importing overcloud images"
  openstack overcloud image upload --image-path /home/stack/images 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
}

function clear_arp_table {
  sudo ip neighbor flush dev eth0
  sudo ip neighbor flush dev br-ctlplane
}

function import_instackenv {
  openstack baremetal import --json /home/stack/instackenv.json 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -ne 0 ]; then
    openstack overcloud node import /home/stack/instackenv.json 2>>$stderr 1>>$stdout
    rc=$?
  fi
  return $rc
}

function configure_boot {
  inc=1
  openstack baremetal configure boot 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -ne 0 ]; then
    inc=0
    rc=0
    for p in $( openstack baremetal node list | grep False | awk '{ print $2 }' ); do
      openstack overcloud node configure $p 2>>$stderr 1>>$stdout
      trc=$?
      if [ $trc -ne 0 ]; then
        rc=$?
      else
        inc=$(( $inc + 1))
      fi
    done
  fi
  if [ $inc -eq 0 ]; then
    rc=255
  fi
  return $rc
}

function introspect {
  openstack baremetal introspection bulk start 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -ne 0 ]; then
    openstack overcloud node introspect --all-manageable --provide 2>>$stderr 1>>$stdout
    rc=$?
  fi
  return $rc
}
function baremetal_setup {
  startlog "Importing instackenv.json"
  import_instackenv
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
    startlog "Configure node boot"
    configure_boot
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
      startlog "Getting nodes information"
      ironic node-list 2>>$stderr 1>>$stdout
      ironic node-list 2>>$stderr | grep False | awk '{ print $2 }' | xargs -I% ironic node-show % 2>>$stderr 1>>$stdout
      endlog "done"
      startlog "Starting introspection"
      introspect
      rc=$?
      if [ $rc -eq 0 ]; then
        endlog "done"
        clear_arp_table
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
  get_oc_images
  rc=$?
  if [ $rc -eq 0 ]; then
    if [ -e "/home/stack/stackrc" ]; then
      upload_oc_images
      rc=$?
      if [ $rc -eq 0 ]; then
        baremetal_setup
        rc=$?
        if [ $rc -eq 0 ]; then
          create_flavors
          rc=$?
          if [ $rc -eq 0 ]; then
            tag_hosts
            rc=$?
            if [ $rc -eq 0 ]; then
              bash deploy_overcloud.sh
              rc=$?
            fi
          fi
        fi
      fi
    fi
  fi
  return $rc
}

function disable_selinux {
  startlog "Disabling selinux"
  sudo sestatus | grep Current | grep -q permissive
  if [ $? -ne 0 ]; then
    sudo setenforce 0
  fi
  grep -q permissive /usr/share/instack-undercloud/puppet-stack-config/os-apply-config/etc/puppet/hieradata/RedHat.yaml
  if [ $? -ne 0 ]; then
    sudo sed -i 's/tripleo::selinux::mode:.*/tripleo::selinux::mode: permissive/' /usr/share/instack-undercloud/puppet-stack-config/os-apply-config/etc/puppet/hieradata/RedHat.yaml
  fi
  grep -q SELINUX=enforcing /etc/selinux/config
  if [ $? -eq 0 ]; then
    sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
  fi
  endlog "done"
}
function install_undercloud {
  startlog "Installing undercloud"
  sudo yum install -y python-rdomanager-oscplugin openstack-utils 2>>$stderr 1>>$stdout
  openstack undercloud install 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
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

function create_local_docker_registry {
  rc=0
  if [ $use_docker -eq 1 ]; then
    if [[ $vernum -lt 13 ]]; then
      if [ $rc -eq 0 ]; then
        rc=255
        startlog "Discover latest container image tag"
        tag=$(sudo openstack overcloud container image tag discover --image ${url}/${releasever}/openstack-base:latest --tag-from-label version-release)
        if [ -z "$tag" ]; then
          tag=$(sudo openstack overcloud container image tag discover --image ${url}/${releasever}/openstack-base:latest --tag-from-label {version}-{release})
          if [ -z "$tag" ]; then
            tag=latest
          fi
        fi
        endlog "done"
        startlog "Preparing local image registry"
        openstack overcloud container image prepare ${extradockerimages} --namespace=${url}/${releasever} --prefix=openstack- --tag=$tag --output-images-file /home/stack/${releasever}/local_registry_images.yaml 2>>$stderr 1>>$stdout
        rc=$?
        if [ $rc -eq 0 ]; then
          endlog "done"
          startlog "Uploading local image registry"
          sudo openstack overcloud container image upload --config-file  /home/stack/${releasever}/local_registry_images.yaml --verbose 2>>$stderr 1>>$stdout
          rc=$?
          if [ $rc -eq 0 ]; then
            endlog "done"
            startlog "Preparing local container image registry"
            openstack overcloud container image prepare --namespace=192.0.2.1:8787/${releasever} --prefix=openstack- --tag=$tag --output-env-file=/home/stack/${releasever}/overcloud_images.yaml 2>>$stderr 1>>$stdout
            rc=$?
            if [ $rc -eq 0 ]; then
              endlog "done"
            else
              endlog "error"
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
    elif [[ $vernum -ge 13 ]]; then
      startlog "Preparing container image configuration files"
      if [ $cephscale -gt 0 ]; then
        cephargs="--set ceph_namespace=registry.access.redhat.com/rhceph --set ceph_image=rhceph-3-rhel7 "
      fi
      openstack overcloud container image prepare ${extradockerimages} ${cephargs} --namespace=${url}/${releasever} --push-destination=192.0.2.1:8787 --prefix=openstack- --tag-from-label {version}-{release} --output-env-file=/home/stack/${releasever}/overcloud_images.yaml --output-images-file /home/stack/local_registry_images.yaml 2>>$stderr 1>>$stdout
      rc=$?
      if [ $rc -eq 0 ]; then
        endlog "done"
        startlog "Uploading images"
        sudo openstack overcloud container image upload --config-file  /home/stack/local_registry_images.yaml --verbose 2>>$stderr 1>>$stdout
        rc=$?
        if [ $rc -eq 0 ]; then
          endlog "done"
        else
          endlog "error"
        fi
      else
        endlog "error"
      fi
    fi
  fi
  return $rc
}


function create_overcloud_route {
  sudo ip addr add 10.1.2.1 dev br-ctlplane 2>>$stderr 1>>$stdout
  sudo route add -net 10.1.2.0 netmask 255.255.255.0 dev br-ctlplane 2>>$stderr 1>>$stdout
}

function get_docker_url {
  if [ $use_docker -eq 1 ]; then
    if [ -e /home/stack/internal ]; then
      url=docker-registry.engineering.redhat.com
    else
      url=registry.access.redhat.com
    fi
  fi
}
function prepare_docker {
  rc=0
  if [ $use_docker -eq 1 ]; then
    if [ -e /home/stack/internal ]; then
      grep -q $url /etc/sysconfig/docker
      rc=$?
      if [ $rc -ne 0 ]; then
        sudo sed -i -e "s/\"$/ --insecure-registry $url\"/" /etc/sysconfig/docker
        rc=$?
        if [ $rc -eq 0 ]; then
          sudo systemctl restart docker
          rc=$?
        fi
      fi
    fi
  fi
  return $rc
}
function prepare_tripleo_docker_images {
  rc=0
  if [ $use_docker -eq 1 ]; then
    if [ $vernum -ge 14 ]; then
      openstack tripleo container image prepare default --output-env-file /home/stack/containers-prepare-parameter.yaml 2>>$stderr 1>>$stdout
      rc=$?
      if [ $rc -eq 0 ]; then
        if [ -e /home/stack/containers-prepare-parameter.yaml ]; then
          if [ -e /home/stack/internal ]; then
            sed -i -e 's/registry.access/docker-registry.engineering/g' /home/stack/containers-prepare-parameter.yaml
            rc=$?
          fi
        else
          rc=255
        fi
      fi
    fi
  fi
  return $rc
}

if [ -e "/home/stack/stackrc" ]; then
  source_rc /home/stack/stackrc
fi

if [[ $releasever =~ rhosp ]]; then
  vernum=$( echo $releasever | sed -e 's/rhosp//' )
fi
conformance
disable_selinux
get_docker_url
prepare_tripleo_docker_images
rc=$?
if [ $rc -eq 0 ]; then
  install_undercloud
  rc=$?
  if [ $rc -eq 0 ]; then
    prepare_docker
    enable_nfs
    source_rc /home/stack/stackrc
    validate_network_environment
    rc=$?
    if [ $rc -eq 0 ]; then
      create_local_docker_registry
      rc=$?
      if [ $rc -eq 0 ]; then
        create_overcloud_route
        deploy_overcloud
        rc=$?
        if [ $rc -eq 0 ]; then
          test_overcloud
          rc=$?
          if [ $rc -eq 0 ]; then
            touch /home/stack/deployment_state/tested
          fi
        fi
      fi
    fi
  fi
fi


exit $rc
