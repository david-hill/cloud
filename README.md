# cloud repository containing various scripts

analyze_failure.sh : Analyze failed overcloud deployment<BR>
cinder_database_cleanup.sh : Delete old volume  entries from cinder database<BR>
watch.sh : Watch an overcloud deployment status<BR>
redeploy_undercloud.sh : Redeploy undercloud<BR>
setup_image.sh : Download cirros and send it to glance<BR>
deploy_overcloud.sh : Deploy the overcloud <BR>
redeploy_overcloud.sh : Delete/Deploy the overcloud <BR>
create_network.sh : Create neutron test network<BR>
delete_network.sh : Delete neutron test network<BR>
boot_vm.sh : Create a test VM<BR>
functions : Contains common functions<BR>
template.xml : Default domain XML template<BR>
create_virsh_vm.sh : Create required virsh VMs for an overcloud deployment<BR>
delete_virsh_vm.sh : Delete virsh VMs of the overcloud deployment<BR>
customize_image.sh : Customize overcloud-full image<BR>
undercloud_database_cleanup.sh : Cleans up mysql database<BR>
update_overcloud.sh : Updates the overcloud<BR>
test_overcloud.sh : Tests the overcloud<BR>

# Requirements
- 9GB of RAM ( 1 undercloud, 3 controllers, 1 compute)<BR>
OR<BR>
- 5GB of RAM ( 1 undercloud, 1 controller, 1 compute)<BR>

# Notes
- Make sure you kill local dnsmasq on the KVM host otherwise you'll have 2 DHCP servers running.<BR>
- Configure a static IP address on the undercloud VM<BR>

# Deploying the Undercloud/Overcloud on a KVM host

The default setup.cfg configuration permits a full Undercloud/Overcloud deployment
on a laptop with 16GB of available RAM.  This is against memory recommendations but
can work at some extent.  32GB of available RAM is recommended in order to allocate
more memory to the controller VMs.

1. git clone https://github.com/david-hill/cloud on the KVM host
2. Generate a root key as root (ssh-keygen -b 2048)
3. Copy the public key on the KVM host in authorized_keys
4. Edit setup.cfg
5. Run create_virsh_vm.sh on the KVM host
6. Run redeploy_undercloud.sh on the KVM undercloud guest
7. In a different window, run "watch.sh" on the KVM undercloud guest 

# Deploying the Undercloud/Overcloud on Baremetal

1. git clone https://github.com/david-hill/cloud on the undercloud host
2. Edit setup.cfg
3. Run redeploy_undercloud.sh
4. In a different window, run "watch.sh"

# Side notes

subscription-manager list --available<BR>
subscription-manager orgs<BR>
