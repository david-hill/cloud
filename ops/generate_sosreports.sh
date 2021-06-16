source stackrc
args="--all-logs"
for p in $(openstack server list -c Networks -f value | sed -e 's/ctlplane=//g'); do 
  echo $p
  ssh heat-admin@$p "sudo sosreport --batch $args"
done

