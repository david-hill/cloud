for stack in $(heat stack-list 2>/dev/null | grep None | awk '{ print $2 }'); do
  complete=0
  servers=
  ports=
  volumes=
  pservers=
  pports=
  pvolumes=
  heat resource-list -n10 $stack 2>/dev/null > /tmp/heat.output.dave
  grep "OS::Nova::Server" /tmp/heat.output.dave | awk '{ print $4 }'> /tmp/heat.output.dave.servers
  grep "OS::Neutron::Port" /tmp/heat.output.dave |awk '{ print $4 }'> /tmp/heat.output.dave.ports
  grep "OS::Cinder::Volume" /tmp/heat.output.dave |awk '{ print $4 }'> /tmp/heat.output.dave.volumes
  for server in $( cat /tmp/heat.output.dave.servers ); do
    nova show $server 2>/dev/null 1>>output.log
    if [ $? -ne 0 ]; then
      complete=1
      servers="$server $servers"
    else
      pservers="$server $pservers"
    fi
  done
  for port in $( cat /tmp/heat.output.dave.ports); do
    neutron port-show $port 2>/dev/null 1>>output.log
    if [ $? -ne 0 ]; then
      complete=1
      ports="$port $ports"
    else
      pports="$port $pports"
    fi
  done
  for volume in $( cat /tmp/heat.output.dave.volumes); do
    cinder show $volume 2>/dev/null 1>>output.log
    if [ $? -ne 0 ]; then
      complete=1
      volumes="$volume $volumes"
    else
      pvolumes="$volume $pvolumes"
    fi
  done
  if [ $complete -ne 0 ]; then
    echo $stack is not complete
    echo Ports: $ports
    echo PPorts: $pports
    echo Servers: $servers
    echo PServers: $pservers
    echo Volumes: $volumes
    echo PVolumes: $pvolumes
  fi
done
