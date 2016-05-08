for p in $(sudo virsh list | grep paused | awk '{ print $1 }'); do 
  sudo virsh resume $p
done
