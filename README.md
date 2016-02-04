# cloud repository containing various scripts


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

# Deploying the Undercloud/Overcloud on a KVM host

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

# Known issues
1. Single controller deployment is not supported
