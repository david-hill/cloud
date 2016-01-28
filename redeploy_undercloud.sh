yum remove -y openstack-* python-oslo-*
yum remove -y mariadb
rm -rf /var/lib/mysql
yum install -y python-rdomanager-oscplugin

source stackrc
openstack undercloud install

git clone https://github.com/rthallisey/clapper
python clapper/network-environment-validator.py

openstack baremetal import --json instackenv.json
openstack baremetal configure boot
openstack baremetal introspection bulk start

for profile in control compute ceph-storage; do
  openstack flavor create --id auto --ram 6144 --disk 40 --vcpus 4 $profile
  openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="$profile" $profile
done

openstack flavor create --id auto --ram 4096 --disk 40 --vcpus 4 baremetal
