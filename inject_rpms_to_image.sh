source functions
source_rc setup.cfg

sudo virt-copy-in -a ../images/overcloud-full.qcow2 ../images/rpms /root/ 2>>$stderr 1>>$stdout
if [ $? -eq 0 ]; then 
  sudo virt-customize -v -a ../images/overcloud-full.qcow2 --run-command 'rpm -Fvh /root/rpms/*rpm; rm -rf /root/rpms' --selinux-relabel 2>>$stderr 1>>$stdout
  if [ $? -eq 0 ]; then
    source ../stackrc
    openstack overcloud image upload --update-existing 2>>$stderr 1>>$stdout
    if [ $? -eq 0 ]; then
      ironic node-list | grep False | awk '{ print $2 }' |  xargs -I% openstack overcloud node configure % 2>>$stderr 1>>$stdout
    fi
  fi
fi

