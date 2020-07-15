cdate=$( date +'%Y%m%d' )
tmpfile=$(mktemp)
tmpfolder=$(mktemp -d)

url=$1
#url=http://download-node-02.eng.bos.redhat.com/brewroot/packages/dbus/1.10.22/1.el7/x86_64/
url=http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/libvirt/6.4.0/1.scrmod+el8.3.0+7066+6dd3ecaa/x86_64/
curl -s $url > $tmpfile

for p in $(cat $tmpfile | grep rpm | awk -F\" '{ print $6 }' | grep -v debuginfo | grep -v "\.src"); do
  wget $url/$p -O $tmpfolder/$p
done

mkdir archive
tar zcvf archive/archive-${cdate}.tgz -C $tmpfolder .

rm -rf $tmpfile
rm -rf $tmpfolder
