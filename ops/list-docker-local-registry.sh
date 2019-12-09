dockerurl=192.0.2.1:8787

function gettags {
   tags=$( curl -s ${dockerurl}/v2/$p/tags/list )
   echo $tags
}


catalog=$( curl -s $dockerurl/v2/_catalog )

for p in $(echo $catalog | sed -e 's/,/\n/g' | sed -e 's/repositories//' -e 's/"//g' -e 's/{:\[//g' -e 's/\]}//g' ); do                                                                    
  gettags
done

