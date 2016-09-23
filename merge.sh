commit=$(git log | grep commit | head -1 | awk '{ print $2 }' )
commit=a83d6e91afb7a30b3bcbe2a9102db334ae953c7c

for p in $(git branch  | awk '{ print $1 }' | grep -v '\*'); do
  echo $p
  git checkout $p
  git pull
  git cherry-pick $commit
  git push
done
