source gnocchirc

function delete_objects {
  container=$1
  ls=10
  while [ $ls -gt 1 ]; do
    timeout 300 swift list $container > output
    split -l1000 output
    ls=$( ls x* | wc -l )
    for p in x*; do
       echo $p
       time  swift delete $container $(cat $p ) > /dev/null
       rm -rf $p
    done
  done
 } 
  
function delete_containers {
  for p in $(swift list ); do 
    echo $p
    time swift delete $p > /dev/null
  done
}

function count_containers {
  var=$( swift list | wc -l )
}

for container in $( openstack container list -f value | grep gnocchi ); do
  delete_objects $container
done

delete_objects measures
count_containers
while [ $var -gt 0 ]; do
  delete_containers
  count_containers
done
