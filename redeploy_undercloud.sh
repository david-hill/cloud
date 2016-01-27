yum remove -y openstack-* python-oslo-*
yum remove -y mariadb

rm -rf /var/lib/mysql

source stackrc

yum install -y python-rdomanager-oscplugin

openstack undercloud install
