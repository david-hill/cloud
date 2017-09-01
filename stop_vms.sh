source functions
source_rc setup.cfg
for p in $(sudo virsh list | grep running | awk '{ print $1 }'); do 
  sudo virsh destroy $p 2>>$stderr 1>>$stdout
done
exit 0
