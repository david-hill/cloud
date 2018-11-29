# very slow
#for port in $( neutron port-list 2>/dev/null | grep subnet | awk '{ print $2 }'); do
#  neutron port-show $port 2>/dev/null | grep -q "binding:vif_type.*unbound"
#  if [ $? -eq 0 ]; then
#    neutron port-delete $port
#  fi
#done

# a bit faster but we need access to ovs_neutron db
for port in $( echo "select id from ports where status = 'DOWN';" | mysql -D ovs_neutron  ); do
  neutron port-show $port 2>/dev/null > /tmp/output_dave_port_blah
  cat /tmp/output_dave_port_blah >> output_port_cleanup_trace
  cat /tmp/output_dave_port_blah | grep -q "binding:vif_type.*unbound"
  if [ $? -eq 0 ]; then
    neutron port-delete $port
  fi
done

