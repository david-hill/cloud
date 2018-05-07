for net in $(heat resource-list case-test 2>/dev/null| grep FAILED | awk '{ print $4 }' ); do
  for port in $(neutron port-list 2>/dev/null | grep $net | awk '{ print $2 }'); do
    neutron port-delete $port
  done
done

heat stack-delete case-test -y

