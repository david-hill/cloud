for p in $(sudo virsh list | grep running | awk '{ print $1 }'); do 
  sudo virsh suspend $p
done
