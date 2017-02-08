commit=$(git log | grep commit | head -1 | awk '{ print $2 }' )
commit=2900d89303a6bf577d73e5ad52c8c655d2f8c5a9

for p in $(git branch  | awk '{ print $1 }' | grep -v '\*'); do
  echo $p
  git checkout $p
  git pull
  git cherry-pick $commit
  git push
done
