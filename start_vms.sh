source functions
source_rc setup.cfg

for p in $(sudo virsh list --all | grep shut | grep $releasever | awk '{ print $2 }'); do 
  sudo virsh start $p
done
