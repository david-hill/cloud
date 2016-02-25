for p in $(sudo virsh list --all | grep shut | awk '{ print $2 }'); do 
  sudo virsh start $p
done
