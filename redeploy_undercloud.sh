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

