#!/bin/bash
## Collect all instance by host and verify the allocation on the placement API

get_hosts () {
  openstack compute service list --service nova-compute -f value -c Host | sort
}

get_resource_providers () {
   openstack resource provider list -f value -c name | sort
}

compare_output () {
  ${3} > /var/tmp/output1
  ${4} > /var/tmp/output2
  echo "${1}         ${2}"
  diff /var/tmp/output1 /var/tmp/output2 -y
}


get_instance_from_host () {
openstack server list -c ID -f value --all-projects --host  ${1} | sort
}

get_allocations_from_host () {
  openstack resource provider show  --allocation -f json $(openstack resource provider list --name ${1} -f value -c uuid) -c allocations |  jq -r '.allocations | keys[]' --raw-output | sort
}

echo "Comparing Compute Service with Resource Providers"
echo "These lists should match"
compare_output "Compute Service" "Resource Provider" get_hosts get_resource_providers

echo "Comparing instances on compute Service with allocations on reoucrces providers"
echo "These should match, if there is a mismatch you could have a missing resource allocation or an resources allocated to a deleted instance"
for providers in $(get_resource_providers);
 do echo "Checking allocations for $providers"
 compare_output  "Instance" "allocation" "get_instance_from_host $providers"  "get_allocations_from_host $providers"
 done

# chmod +x placement-allocation.sh
# ./placement-allocation.sh
