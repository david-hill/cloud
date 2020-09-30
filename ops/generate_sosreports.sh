source stackrc
for p in $(openstack server list -c Networks -f value | sed -e 's/ctlplane=//g'); do 
  echo $p
  ssh heat-admin@$p "sudo -s bash -c sosreport --batch"
done

