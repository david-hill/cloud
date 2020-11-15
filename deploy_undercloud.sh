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
  rc=0
  startlog "Updating system"
  sudo yum update -y 2>>$stderr 1>>$stdout
  rc=$?
  endlog "done"
  rhel_release
  rc=$?
  if [ $rc -eq 7 ]; then
    startlog "Installing various packages"
    sudo yum install -y ntpdate ntp screen libguestfs-tools wget vim 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
      startlog "Synching time"
      sudo service ntpd stop 2>>$stderr 1>>$stdout
      sudo ntpdate $ntpserver 2>>$stderr 1>>$stdout
      sudo service ntpd start 2>>$stderr 1>>$stdout
      endlog "done"
    else
      endlog "error"
    fi
  elif [ $rc -eq 8 ]; then
    startlog "Installing various packages"
    sudo yum install -y tmux libguestfs-tools wget vim 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
      startlog "Synching time"
      sudo service chronyd stop 2>>$stderr 1>>$stdout
      sudo chronyd -q 2>>$stderr 1>>$stdout
      sudo service chronyd start 2>>$stderr 1>>$stdout
      endlog "done"
    else
      endlog "error"
    fi
  else
    rc=255
  fi
  return $rc
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
    openstack flavor set $profile --property resources:CUSTOM_BAREMETAL=1
    openstack flavor set $profile --property resources:VCPU=0
    openstack flavor set $profile --property resources:MEMORY_MB=0
    openstack flavor set $profile --property resources:DISK_GB=0
  done
  openstack flavor delete baremetal 2>>$stderr 1>>$stdout
  if [ $? -ne 0 ]; then
    nova flavor-delete baremetal 2>>$stderr 1>>$stdout
  fi
  openstack flavor create --id auto --ram $bram --disk $disk --vcpus $vcpus --swap $swap baremetal 2>>$stderr 1>>$stdout
  if [ $? -ne 0 ]; then
    nova flavor-create --swap $swap baremetal auto $bram $disk $vcpus 2>>$stderr 1>>$stdout
  fi
  openstack flavor set baremetal --property resources:CUSTOM_BAREMETAL=1
  openstack flavor set baremetal --property resources:VCPU=0
  openstack flavor set baremetal --property resources:MEMORY_MB=0
  openstack flavor set baremetal --property resources:DISK_GB=0
  endlog "done"
  return $rc
}

function tag_from_name {
  inc=0
  for role in compute control ceph swift block; do
    list=$( openstack baremetal node list 2>>$stderr | grep $role | awk '{ print $2 }' )
    for server in $list; do
      if [[ $role =~ ceph ]]; then
	thisrole=ceph-storage
      elif [[ $role =~ swift ]]; then
	thisrole=swift-storage
      elif [[ $role =~ block ]]; then
	thisrole=blocks-storage
      else
	thisrole=$role
      fi
      openstack baremetal node set --property capabilities="profile:$thisrole,boot_option:local,boot_mode:${boot_mode}" $server 2>>$stderr 1>>$stdout
      if [ $? -eq 0 ]; then
        inc=$( expr $inc + 1)
      fi
    done
  done
  return $inc
}

function tag_hosts {
  startlog "Tagging hosts"
  inc=0
  tag_from_name
  rc=$?
  if [ $rc -eq 0 ]; then
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
      if [ $inc -lt 3 -a $controlscale -eq 3 ] || [ $inc -lt 5 -a $controlscale -eq 5 ] || [ $controlscale -eq 1 -a $inc -lt 1 ]; then
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
  fi
  if [ $inc -eq 0 ]; then
    endlog "error"
    rc=1
  else
    endlog "done"
    rc=0
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
  for dev in $( /sbin/ip a | grep "^[0-9]*:" | awk -F: '{ print $2 }' ); do
    sudo ip neighbor flush dev $dev
  done
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
    for p in $( openstack baremetal node list 2>>$stderr | grep False | awk '{ print $2 }' ); do
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
  grep -q permissive /usr/share/instack-undercloud/puppet-stack-config/os-apply-config/etc/puppet/hieradata/RedHat.yaml 2>>$stderr
  if [ $? -ne 0 ]; then
    sudo sed -i 's/tripleo::selinux::mode:.*/tripleo::selinux::mode: permissive/' /usr/share/instack-undercloud/puppet-stack-config/os-apply-config/etc/puppet/hieradata/RedHat.yaml 2>>$stderr
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
  rhel_release
  rc=$?
  if [ $rc -eq 7 ]; then
    startlog "Validating network environment"
    git clone https://github.com/rthallisey/clapper 2>>$stderr 1>>$stdout
    python clapper/network-environment-validator.py -n ../$releasever/network-environment.yaml 2>>$stderr 1>>$stdout
    rc=$?
    if [ $rc -eq 0 ]; then
      endlog "done"
    else
      endlog "error"
    fi
  else
    rc=0
  fi
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


function set_docker_namespace {
  file=$1
  sed -i -e "s/ namespace: registry.access.*/ namespace: $url\/$releasever/g" $file
  return $?
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
          set_docker_namespace /home/stack/${releasever}/local_registry_images.yaml
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
      if [ ! -e /home/stack/containers-prepare-parameter.yaml ]; then
        startlog "Preparing container image configuration files"
        if [ $cephscale -gt 0 ]; then
          cephargs="--set ceph_namespace=registry.access.redhat.com/rhceph --set ceph_image=rhceph-3-rhel7 "
        fi
        openstack overcloud container image prepare ${cephargs} ${extradockerimages} --namespace=${url}/${releasever} --push-destination=192.0.2.1:8787 --prefix=openstack- --tag-from-label {version}-{release} --output-env-file=/home/stack/${releasever}/overcloud_images.yaml --output-images-file /home/stack/local_registry_images.yaml 2>>$stderr 1>>$stdout
        rc=$?
        if [ $rc -eq 0 ]; then
          set_docker_namespace /home/stack/${releasever}/overcloud_images.yaml
          endlog "done"
          startlog "Uploading images"
          sudo openstack overcloud container image upload --config-file  /home/stack/local_registry_images.yaml --verbose 2>>$stderr 1>>$stdout
          rc=$?
          if [ $rc -eq 0 ]; then
            endlog "done"
            if [[ $vernum -ge 14 ]] ; then
              if [ ! -e /home/stack/$releasever/containers-prepare-parameter.yaml ]; then
                openstack tripleo container image prepare default --local-push-destination --output-env-file /home/stack/$releasever/containers-prepare-parameter.yaml 2>>$stderr 1>>$stdout
                set_docker_namespace /home/stack/$releasever/containers-prepare-parameter.yaml
                if [[ $deploymentargs =~ ovn ]]; then
                  sed -i -E 's/neutron_driver:([ ]\w+)/neutron_driver: ovn/' /home/stack/$releasever/containers-prepare-parameter.yaml
                fi
              fi
            fi
          else
            endlog "error"
          fi
        else
          endlog "error"
        fi
      else
        rm -rf /home/stack/${releasever}/overcloud_images.yaml
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
      if [ -z $dockerregistry ]; then
	      if [ "$alpha" -eq 1 ]; then
          #url=registry.redhat.io/rhosp-beta
          url=registry-proxy.engineering.redhat.com/rh-osbs
          #url=brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888
        else
          url=docker-registry.engineering.redhat.com
        fi
      else
        url=$dockerregistry
      fi
    else
      url=registry.access.redhat.com
    fi
  fi
  dockerregistry=$url
}
function prepare_docker {
  rc=0
  if [ $use_docker -eq 1 ]; then
    if [ -e /home/stack/internal ]; then
      rhel_release
      rc=$?
      if [ $rc -eq 7 ]; then
        grep -q $url /etc/sysconfig/docker 2>>/dev/null
        rc=$?
        if [ $rc -ne 0 ]; then
          sudo sed -i -e "s/\"$/ --insecure-registry $url\"/" /etc/sysconfig/docker
          rc=$?
          if [ $rc -eq 0 ]; then
            sudo systemctl restart docker
            rc=$?
          fi
        fi
      else
        rc=0
      fi
    fi
  fi
  return $rc
}
function prepare_tripleo_docker_images {
  rc=0
  if [ $use_docker -eq 1 ]; then
    if [ $vernum -ge 14 ]; then
      openstack tripleo container image prepare default --local-push-destination --output-env-file /home/stack/containers-prepare-parameter.yaml 2>>$stderr 1>>$stdout
      rc=$?
      if [ $rc -eq 0 ]; then
        if [ $vernum -ge 15 ]; then
          source /home/stack/rhnlogin
          cat << EOF >> /home/stack/containers-prepare-parameter.yaml
  ContainerImageRegistryCredentials:
    registry.redhat.io:
      ${rhnusername}: "$rhnpassword"
EOF
        fi
        if [ -e /home/stack/containers-prepare-parameter.yaml ]; then
          if [ ! -z "$neutron_driver" ]; then
              sed -i -e "s#neutron_driver: .*#neutron_driver: $neutron_driver#" /home/stack/containers-prepare-parameter.yaml
          fi
          if [ -e /home/stack/internal ]; then
            if [ $vernum -ge 16 ]; then
              sed -i -e "s# namespace: registry.access.*# namespace: $dockerregistry#g" /home/stack/containers-prepare-parameter.yaml
              rc=$?
              sed -i -e "s# namespace: registry.redhat.*# namespace: $dockerregistry#g" /home/stack/containers-prepare-parameter.yaml
              rc=$?
              sed -i "s/tag: '1.*'/tag: '$minorver'/g" /home/stack/containers-prepare-parameter.yaml
              rc=$?
            else
              sed -i -e "s/ namespace: registry.access.*/ namespace: $dockerregistry\/$releasever/g" /home/stack/containers-prepare-parameter.yaml
              rc=$?
              sed -i -e "s/ namespace: registry.redhat.*/ namespace: $dockerregistry\/$releasever/g" /home/stack/containers-prepare-parameter.yaml
              rc=$?
            fi
            #sed -i -e "s/ ceph_namespace: .*/ ceph_namespace: docker-registry.engineering.redhat.com\/ceph\//g" /home/stack/containers-prepare-parameter.yaml
            #rc=$?
            #sed -i -e "s/rhceph-4.0-rhel8/rhceph-4-rhel8/g" /home/stack/containers-prepare-parameter.yaml
            #rc=$?
            if [ $vernum -ge 16 ]; then
            #  sed -i -e "s/ ceph_namespace: .*/ ceph_namespace: registry.redhat.io\/rhceph-beta/g" /home/stack/containers-prepare-parameter.yaml
            #  rc=$?
            #  sed -i -e "s/rhceph-4.0-rhel8/rhceph-4-rhel8/g" /home/stack/containers-prepare-parameter.yaml
            #  rc=$?
            #  sed -i -e "s/ceph_tag: .*/ceph_tag: 4-8/g" /home/stack/containers-prepare-parameter.yaml
            #  rc=$?
            # ceph_alertmanager_image: openshift-ose-prometheus-alertmanager
            # ceph_alertmanager_namespace: rhos-qe-mirror-rdu2.usersys.redhat.com:5002/rh-osbs
            # ceph_alertmanager_tag: v4.1
            # ceph_grafana_image: rhceph-3-dashboard-rhel7
            # ceph_grafana_namespace: registry.access.redhat.com/rhceph
            # ceph_grafana_tag: 3
            # ceph_node_exporter_image: openshift-ose-prometheus-node-exporter
            # ceph_node_exporter_namespace: rhos-qe-mirror-rdu2.usersys.redhat.com:5002/rh-osbs
            # ceph_node_exporter_tag: v4.1
            # ceph_prometheus_image: openshift-ose-prometheus
            # ceph_prometheus_namespace: rhos-qe-mirror-rdu2.usersys.redhat.com:5002/rh-osbs
            # ceph_prometheus_tag: v4.1
              sed -i -e "s#ceph_namespace: .*#ceph_namespace: registry-proxy.engineering.redhat.com/rh-osbs#" /home/stack/containers-prepare-parameter.yaml
              rc=$?
              sed -i -e "s/ceph_image: .*/ceph_image: rhceph/g" /home/stack/containers-prepare-parameter.yaml
              rc=$?
              sed -i -e "s/ceph_tag: .*/ceph_tag: latest/g" /home/stack/containers-prepare-parameter.yaml
              rc=$?
              sed -i -e "s/name_prefix: .*/name_prefix: rhosp$vernum-openstack-/g" /home/stack/containers-prepare-parameter.yaml
              rc=$?
              sed -i -e "s/\(tag_from_label: .*\)/#\1/" /home/stack/containers-prepare-parameter.yaml
              rc=$?
              sed -i -e "s/tag: '1.*/tag: '$minorver'/" /home/stack/containers-prepare-parameter.yaml
              rc=$?
            fi
          else
            if [[ $releasever =~ beta ]]; then
              sed -i "s/tag: '16.0'/tag: '16.1'/g" /home/stack/containers-prepare-parameter.yaml
              rc=$?
              sed -i "s# namespace: registry.redhat.io/.*#namespace: registry.redhat.io/rhosp-beta#g" /home/stack/containers-prepare-parameter.yaml
              rc=$?
            fi
          fi
        else
          rc=255
        fi
      fi
    fi
  fi
  return $rc
}

function configure_ironic_cleaning_network {
  startlog "Configuring cleaning_network_uuid"
  rc=255
  sudo grep -q "^#cleaning_network_uuid =" /etc/ironic/ironic.conf 2>>$stderr
  if [ $? -eq 0 ]; then
    cnu=$( neutron net-list | grep ctlplane | awk '{ print $2 }' )
    if [ ! -z "$cnu" ]; then
      sudo sed -i "s/^#cleaning_network_uuid = .*/cleaning_network_uuid = $cnu/" /etc/ironic/ironic.conf
      rc=$?
      if [ $rc -eq 0 ]; then
        sudo systemctl restart openstack-ironic-conductor
        rc=$?
      fi
    fi
  else
    rc=0
  fi
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
}

if [ -e "/home/stack/stackrc" ]; then
  source_rc /home/stack/stackrc
fi

if [[ $releasever =~ rhosp ]]; then
  if [[ $releasever =~ beta ]]; then
    vernum=16
  else
    vernum=$( echo $releasever | sed -e 's/rhosp//' )
  fi
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
      configure_ironic_cleaning_network
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
