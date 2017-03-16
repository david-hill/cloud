commit=$(git log | grep commit | head -1 | awk '{ print $2 }' )
commit=007c1bfc406a452980e633162201f2668339bf7c

for p in $(git branch  | awk '{ print $1 }' | grep -v '\*'); do
  echo $p
  git checkout $p
  git pull
  git cherry-pick $commit
  git push
done
