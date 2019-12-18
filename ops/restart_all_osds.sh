!/bin/bash

controller=192.0.2.6
storagename=stor

function cluster_health {
  rc=1
  output=$(ssh heat-admin@$controller 'sudo ceph -s | grep HEALTH_OK')
  if $( echo $output | grep -q HEALTH_OK ); then
    rc=0
  fi
  echo -n "."
  return $rc
}


for server in $( nova list | grep $storagename | awk '{ print $12 }' | sed -e 's/ctlplane=//g' ); do
  echo  Processing $server
  ssh heat-admin@$server "sudo find /var/lib/ceph/tmp/ -name tmp.* -type d -empty -exec rm -rf {} \; 2>/dev/null"
  for osd in $( ssh heat-admin@$server "sudo docker ps | grep ceph-osd | awk '{ print \$1 } ' "); do
    rc=1
    echo -n "Restarting $osd"
    ssh heat-admin@$server "sudo docker restart $osd > /dev/null"
    sleep 5
    while [ $rc -eq 1 ]; do
      cluster_health
      rc=$?
    done
    echo "done"
  done
done

