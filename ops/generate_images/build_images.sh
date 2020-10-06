export DIB_LOCAL_IMAGE=/home/stack/images/rhel-guest-image-local.qcow2
export DIB_REG_TYPE=portal
export REG_METHOD=portal
export REG_USER=username
#export DIB_RHSM_USER=username
#export DIB_RHSM_PASSWORD='password'
export REG_PASSWORD='password'
#export DIB_RHSM_POOL=8a85f9833e1404a9013e3cddf99305e6
export REG_POOL_ID=8a85f9833e1404a9013e3cddf99305e6
#export DIB_RHN_CHANNELS="rhel-7-server-rpms rhel-7-server-extras-rpms rhel-7-server-rh-common-rpms rhel-ha-for-rhel-7-server-rpms rhel-7-server-openstack-13-rpms rhel-7-server-rhceph-3-mon-rpms rhel-7-server-rhceph-3-osd-rpms rhel-7-server-rhceph-3-tools-rpms rhel-7-server-nfv-rpms rhel-ha-for-rhel-7-server-rpms rhel-7-server-satellite-tools-6.3-rpms"
export REG_REPOS="rhel-7-server-rpms rhel-7-server-extras-rpms rhel-7-server-rh-common-rpms rhel-ha-for-rhel-7-server-rpms rhel-7-server-openstack-13-rpms rhel-7-server-rhceph-3-mon-rpms rhel-7-server-rhceph-3-osd-rpms rhel-7-server-rhceph-3-tools-rpms  rhel-7-server-nfv-rpms rhel-ha-for-rhel-7-server-rpms rhel-7-server-satellite-tools-6.3-rpms"

openstack --debug overcloud image build --config-file harden_images_uefi.yaml
