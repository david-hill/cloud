if [ ! -d images ]; then
  mkdir images
fi

if [ ! -e images/cirros-0.3.4-x86_64-disk.img ]; then
  cd images
  wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
  cd ..
fi

glance image-create --name "cirros-0.3.4-x86_64" --file images/cirros-0.3.4-x86_64-disk.img --disk-format qcow2 --container-format bare --is-public True --progress
