for p in $( vbmc list | grep rhosp | grep down | awk '{ print $6 }' ); do
  echo Add $p to virbr0
  ip a add $p/32 dev virbr0
done

for p in $( vbmc list | grep rhosp | grep down | awk '{ print $2 }' ); do
  echo Start $p
  vbmc start $p
done

