yum remove -y openstack-* python-oslo-*
yum remove -y mariadb

rm -rf /var/lib/mysql

source stackrc

yum install -y python-rdomanager-oscplugin

openstack undercloud install

git clone https://github.com/rthallisey/clapper

python clapper/network-environment-validator.py
