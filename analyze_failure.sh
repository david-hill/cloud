source functions

source_rc setup.cfg
source_rc /home/stack/stackrc

for stack in $(heat stack-list | grep -i failed | awk '{ print $2 }'); do 
  for nstack in $(heat stack-list --show-nested | grep $stack | grep -i failed | awk '{ print $2 }'); do
    for resource in $( heat resource-list -n10 $nstack | grep -i failed | awk '{ print $2 }'); do
      deployments=$(heat resource-list -n10 $nstack | grep -i failed | grep -i $resource | grep Deployment | awk '{ print $4 }')
      if [ ! -z "$deployments"  ]; then
        for deployment in $deployments; do
          heat deployment-show $deployment
        done
      fi
    done
  done
done
