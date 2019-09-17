source gnocchirc

ls=10

while [ $ls -gt 0 ]; do
   timeout 300 swift list measure > output
   split -l1000 output
   ls=$( ls x* | wc -l )

   for p in x*; do
      echo $p
      time  swift delete measure $(cat $p ) > /dev/null
      rm -rf $p
   done
done


for p in $(swift list | grep gnocchi ); do 
  echo $p
  time swift delete $p
done

