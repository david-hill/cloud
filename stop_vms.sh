for p in $(sudo virsh list | grep running | awk '{ print $1 }'); do 
  sudo virsh destroy $p
done
