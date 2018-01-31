source functions
source_rc setup.cfg
for p in $(sudo virsh list | grep running | awk '{ print $1 }'); do 
  sudo virsh destroy $p 2>>$stderr 1>>$stdout
  rc=$?
done

if [ $rc -eq 0 ]; then
  rc=255
  timeout=60
  while [ $timeout -ne 0 ] && [ $rc -ne 0 ]; do
    sudo virsh list | grep -q "in shutdown"
    if [ $? -eq 0 ]; then
      rc=255
    else
      rc=0
    fi
    sleep 1
    timeout=$(( $timeout - 1 ))
  done
fi
exit $rc
