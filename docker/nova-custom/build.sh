tag=192.0.2.1:8787/rhosp15/openstack-nova-compute-ironic:15.0-36

for img in $(  sudo podman image list | grep none |  awk '{ print $3 }' ); do
  sudo podman image rm $img
done

sudo yum download patch patchutils

sudo podman build  . --tag $tag

for img in $(  sudo podman image list | grep none |  awk '{ print $3 }' ); do
  sudo podman image tag $img $tag
done

sudo rm -rf *.rpm
