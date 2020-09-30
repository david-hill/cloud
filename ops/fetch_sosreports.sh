source /home/stack/stackrc

for p in $(openstack server list -c Networks -f value | sed -e 's/ctlplane=//g'); do 
  echo $p;
  ssh heat-admin@$p 'sudo -s bash -c "whoami; chmod 666 /var/tmp/sosreport*; ls -latr /var/tmp/sosreport*"'
  scp heat-admin@$p:/var/tmp/sosreport-* .
done
