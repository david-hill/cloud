#commit=$(git log | grep commit | head -1 | awk '{ print $2 }' )
commit=ab15f375fd5bc37d6bfccc9b13b6db8bd36d145c

for p in $(git branch  | awk '{ print $1 }' | grep -v '\*'); do
  echo $p
  git checkout $p
  git pull
  git cherry-pick $commit
  git push
done
