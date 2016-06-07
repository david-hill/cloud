url=http://rhos-release.virt.bos.redhat.com/puddle-images/8.0/

rm -rf index.html
wget -q $url
for folder in $(cat index.html | grep DIR | awk -F\" '{ print $8 }'); do
  if [[ $folder =~ test ]]; then
    continue;
  fi
  if [ -e CHECKSUM ]; then
    rm -rf CHECKSUM
  fi
  wget -q $url/${folder}images/CHECKSUM
  folder=`echo $folder | sed -e 's/\///' -e 's/^/8.0-/'`
  if [ -e backup/$folder ]; then
    for file in $(ls backup/$folder); do
      sum=$(md5sum backup/$folder/$file | awk '{ print $1 }')
      grep $file CHECKSUM | grep -q $sum
      if [ $? -ne 0 ]; then
        echo backup/$folder/$file has different checksum
      else
        echo backup/$folder/$file with $sum is same
      fi
    done
  fi
done 






