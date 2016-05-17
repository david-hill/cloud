source_rc setup.cfg
source_rc functions
for p in $(sudo virsh list | grep running | awk '{ print $1 }'); do 
  sudo virsh destroy $p 2>$stderr 1>$stdout
done
