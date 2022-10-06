rm -rf rhosp*report

for p in rhosp10; do
#for p in rhosp7 rhosp8 rhosp9 rhosp10 rhosp11 rhosp12 rhosp13 rhosp14 rhosp15 rhosp16; do
  git clone https://github.com/david-hill/$p
  mkdir $p.new
  cd $p.new
  git init .
  git commit -a -m "Initialisation commit (not initial)"
  cd ../$p
  for q in $( git branch -r | grep -v HEAD | awk '{ print $1 }'); do 
    cd ../$p.new
    r=$( echo $q | sed -e 's/origin\///'); 
    git checkout -b $r
    cd ../$p
    git checkout $r
    cp -pr * ../$p.new/
    cd ../$p.new
    git add * 
    git commit -a -m "Initial commit in $q"
    cd ../$p
    git branch --force -D $r
  done
  git branch --force -D master
  cd ..
  cd $p.new
  git remote add origin https://$username:$password@github.com/david-hill/$p.git
  for s in $( git branch ); do
    git push --set-upstream --force origin $s
  done
  cd ..
done

#for p in rhosp*; do 
#  rm -rf $p
#  git clone https://github.com/david-hill/$p
#  sed -i -e 's/github/$username:$password@github/' $p/.git/config
#  cd $p; 
#  for q in $( git branch -r | awk '{ print $1 }'); do 
#    r=$( echo $q | sed -e 's/origin\///'); 
#    git checkout $r
#    git pull --allow-unrelated-histories
#    if [ $? -ne 0 ]; then
#      exit
#    fi
#    sed -i 's/rhel_reg_password: .*/rhel_reg_password: "***REMOVED***"/g' rhel-registration/environment-rhel-registration.yaml
#    sed -i 's/rhel_reg_activation_key: .*/rhel_reg_activation_key: "***REMOVED***"/g' rhel-registration/environment-rhel-registration.yaml
#    sed -i 's/rhel_reg_user: .*/rhel_reg_user: "***REMOVED***"/g' rhel-registration/environment-rhel-registration.yaml
#    git commit -a -m "."; 
#    git push --set-upstream origin $r
#  done; 
#  cd ..
#done
#
#for p in rhosp*; do
#  java -jar bfg-1.13.0.jar --replace-text passwords.txt --no-blob-protection  $p
##  java -jar bfg-1.13.0.jar --replace-text passwords.txt   $p
#  cd $p 
#  git pull --allow-unrelated-histories
#  git reflog expire --expire=now --all 
#  git gc --prune=now --aggressive
#  git commit -a -m "."
#  git push
#  cd ..
#done
