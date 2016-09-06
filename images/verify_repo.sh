repos=$1
rc=255
for r in `echo ${repos}`; do
  r=${r//rdo-/}
  curl -s -L -o current.txt http://buildlogs.centos.org/centos/7/cloud/x86_64/?C=M;O=A
  this_date=$(cat current.txt | grep $r | awk -F\" '{ print $11 }' | awk -F\> '{ print $2 }' | awk '{ print $1 }' | tail -1)
  if [ ! -e ${r}.last ]; then
    echo "$this_date" > ${r}.last
    rc=0
  else
    that_date=$(cat ${r}.last)
    if [ "$this_date" != "$that_date" ]; then
      rc=0
      echo "$this_date" > ${r}.last
    fi
  fi
done

exit $rc
