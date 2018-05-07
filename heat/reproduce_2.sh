function do_ping {
  inc=0
  rc=1
  while [ $inc -lt 10 ] && [ $rc -ne 0 ]; do
    echo "ping $ip - $inc"
    ping -c1 $ip
    rc=$?
    inc=$(( $inc + 1 ))
  done
  return $rc
}


heat stack-create -f architecture-no-vol.yaml test
if [ $? -eq 0 ]; then

  completed=1
  
  while [ $completed -eq 1 ]; do
    heat stack-list | grep COMPLETE
    completed=$?
  done
  
#  neutron port-list > after
#  
#  ip=$(diff before after | grep 10.0.0 | awk -F\| '{ print $5 }' | awk -F\" '{ print $8 }' | tail -1 )
#  
#  
#  do_ping $ip
#  if [ $? -eq 0 ]; then
#    echo worked
#  
    heat stack-delete -y test
#    
    completed=0
    while [ $completed -eq 0 ]; do
      heat stack-list | grep test
      completed=$?
    done
#  fi
fi
