cdate=$( date +'%Y%m%d' )
tmpfile=$(mktemp)
tmpfolder=$(mktemp -d)

url=$1
#url=http://download-node-02.eng.bos.redhat.com/brewroot/packages/dbus/1.10.22/1.el7/x86_64/
url=http://download-node-02.eng.bos.redhat.com/brewroot/packages/openstack-neutron-lbaas/9.2.2/7.el7/noarch/
curl -s $url > $tmpfile

for p in $(cat $tmpfile | grep rpm | awk -F\" '{ print $6 }' | grep -v "\.src"); do
  wget $url/$p -O $tmpfolder/$p
done

mkdir archive
tar zcvf archive/archive-${cdate}.tgz -C $tmpfolder .

rm -rf $tmpfile
rm -rf $tmpfolder
