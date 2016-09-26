commit=$(git log | grep commit | head -1 | awk '{ print $2 }' )

for p in $(git branch  | awk '{ print $1 }' | grep -v '\*'); do
  echo $p
  git checkout $p
  git pull
  git cherry-pick $commit
  git push
done
