function cleanup_undercloud {
  rm overcloudrc
  yum remove -y openstack-* python-oslo-*
  yum remove -y mariadb
  rm -rf /var/lib/mysql
  yum install -y python-rdomanager-oscplugin
}

function delete_overcloud {
  heat=$( heat stack-list | grep overcloud )
  if [ ! -z "$heat" ]; then
    heat stack-delete overcloud
    while [ ! -z "$heat" ]; do
      heat=$( heat stack-list | grep overcloud )
      echo -n "."
      if [[ "$heat" =~ FAILED ]]; then
        echo "Stack deletion failed... retrying!"
        heat stack-delete overcloud
      fi
    done
  fi
}

function create_flavors {
    for profile in control compute ceph-storage; do
      openstack flavor create --id auto --ram 6144 --disk 40 --vcpus 4 $profile
      openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="$profile" $profile
    done

    openstack flavor create --id auto --ram 4096 --disk 40 --vcpus 4 baremetal
}

function tag_hosts {
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
    openstack overcloud image upload --image-path /home/stack/images
}

function baremetal_setup {
    openstack baremetal import --json /home/stack/instackenv.json
    openstack baremetal configure boot
    openstack baremetal introspection bulk start
}

function test_overcloud {
    if [ -e ~/overcloudrc ]; then
      source ~/overcloudrc
      bash setup_images.sh
      bash create_network.sh
      bash boot_vm.sh
    else
      echo "Something weird happened"
    fi
}

function deploy_overcloud {
  if [ -d  /home/stack/images ]; then
    if [ -e ~/overcloudrc ]; then
      create_oc_images()
      baremetal_setup()
      create_flavors()
      tag_hosts()
      bash create.sh
    else 
      echo "Undercloud wasn't successfully deployed!"
    fi
  else
    echo "Please download the overcloud-* images and put them in /home/stack/images"
  fi
}

function install_undercloud {
  openstack undercloud install
}

function validate_network_environment {
  git clone https://github.com/rthallisey/clapper
  python clapper/network-environment-validator.py
}

delete_overcloud()
cleanup_undercloud()
install_undercloud()
validate_network_environment()
deploy_overcloud()
test_overcloud()
