commits=$(git log | grep commit | head -1 | awk '{ print $2 }' )


for p in $(git branch  | awk '{ print $1 }' | grep -v '\*'); do
  git checkout $p
  git pull
  for commit in $commits; do
    git cherry-pick $commit
    if [ $? -ne 0 ]; then
      git reset --hard
      git push
    fi
  done
done
