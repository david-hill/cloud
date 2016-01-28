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

rm overcloudrc

yum remove -y openstack-* python-oslo-*
yum remove -y mariadb
rm -rf /var/lib/mysql
yum install -y python-rdomanager-oscplugin

source stackrc
openstack undercloud install

git clone https://github.com/rthallisey/clapper
python clapper/network-environment-validator.py

openstack overcloud image upload --image-path /home/stack/images
openstack baremetal import --json instackenv.json
openstack baremetal configure boot
openstack baremetal introspection bulk start

for profile in control compute ceph-storage; do
  openstack flavor create --id auto --ram 6144 --disk 40 --vcpus 4 $profile
  openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="$profile" $profile
done

openstack flavor create --id auto --ram 4096 --disk 40 --vcpus 4 baremetal

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

bash create.sh

if [ -e overcloudrc ]; then
	bash setup_images.sh
        bash create_network.sh
        bash boot_vm.sh
fi
