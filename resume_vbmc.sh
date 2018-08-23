for p in $( vbmc list | grep rhosp | grep down | awk '{ print $6 }' ); do
  ip a  | grep -q "$p/32"
  if [ $? -ne 0 ]; then
    echo Add $p to virbr0
    ip a add $p/32 dev virbr0
  fi
done

for p in $( vbmc list | grep rhosp | grep down | awk '{ print $2 }' ); do
  vbmc show $p | grep -q "status.*down"
  if [ $? -eq 0 ]; then
    echo Start $p
    vbmc start $p
  fi
done

