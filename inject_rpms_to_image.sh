virt-copy-in -a ../images/overcloud-full.qcow2 rpms /root/
if [ $? -eq 0 ]; then 
  virt-customize -v -a ../images/overcloud-full.qcow2 --run-command 'rpm -Fvh /root/rpms/*rpm; rm -rf /root/rpms' --selinux-relabel
  if [ $? -eq 0 ]; then
    source ../stackrc
    openstack overcloud image upload --update-existing
    if [ $? -eq 0 ]; then
      ironic node-list | grep False | awk '{ print $2 }' |  xargs -I% openstack overcloud node configure %
    fi
  fi
fi

