cdate=$( date +'%Y%m%d' )
tmpfile=$(mktemp)
tmpfolder=$(mktemp -d)

url=$1
url=http://download-node-02.eng.bos.redhat.com/brewroot/packages/openstack-nova/12.0.6/22.el7ost/data/signed/f21541eb/noarch/
curl -s $url > $tmpfile

for p in $(cat $tmpfile | grep rpm | awk -F\" '{ print $6 }'); do
  wget $url/$p -O $tmpfolder/$p
done

mkdir archive
tar zcvf archive/archive-${cdate}.tgz -C $tmpfolder .

rm -rf $tmpfile
rm -rf $tmpfolder
