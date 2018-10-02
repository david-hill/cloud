for p in $( vbmc list | grep rhosp | grep down | awk '{ print $6 }' ); do
  ip a  | grep -q "$p/32"
  if [ $? -ne 0 ]; then
    echo Add $p to virbr0
    ip a add $p/32 dev virbr0
  fi
done

function start_vbmc {
  p=$1
  inc=$2
  inc=$(( $inc + 1 ))
  if [ $inc -lt 3 ]; then
    vbmc show $p | grep -q "status.*down"
    if [ $? -eq 0 ]; then
      echo Start $p
      vbmc start $p
      vbmc show $p | grep -q "status.*down"
      if [ $? -eq 0 ]; then
        sleep 1
        start_vbmc $p $inc
      fi 
    fi
  fi
}


for p in $( vbmc list | grep rhosp | grep down | awk '{ print $2 }' ); do
  start_vbmc $p 0
done

