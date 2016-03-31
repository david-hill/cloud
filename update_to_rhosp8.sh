rc=0
function patch_openstack {
  rc=255
  this_patch=$1
  url=$2
  diff=$3
  pushd /usr/share/openstack-tripleo-heat-templates
  sudo curl -o $this_patch $url
  if [ $? -eq 0 ]; then
    sudo unzip $this_patch
    if [ $? -eq 0 ]; then
      sudo patch -p1 < $diff
      if [ $? -eq 0 ]; then
        rc=0
      fi
    fi
  fi
  popd
  return $rc
}
function patch_code {
  rc=255
  sudo cp -r /usr/share/openstack-tripleo-heat-templates /usr/share/openstack-tripleo-heat-templates.BACKUP
  if [ $? -eq 0 ]; then
    patch_openstack "patch1.diff.zip" "https://review.openstack.org/changes/298685/revisions/1b3e799ed3922ac06dd29d7145b8a5555552f6d4/patch?zip" "1b3e799e.diff"
    if [ $? -eq 0 ]; then
      patch_openstack "patch2.diff.zip" "https://review.openstack.org/changes/298695/revisions/7b2e56053f6cf7535c7ae416c5cb41e7c9679924/patch?zip" "7b2e5605.diff"
      if [ $? -eq 0 ]; then
        patch_openstack "patch3.diff.zip" "https://review.openstack.org/changes/299303/revisions/537aaab152125498f550a48c76c8d2984bc70df8/patch?zip" "537aaab1.diff"
        rc=0
      fi
    fi
  fi
  return $rc
}


cat << EOF >/home/stack/rhosp8/rhos-release-8.yaml
parameter_defaults:
  UpgradeInitCommand: |
    set -e
    rpm -ivh http://rhos-release.virt.bos.redhat.com/repos/rhos-release/rhos-release-latest.noarch.rpm || true  # rpm -i will return 1 if already installed
    rhos-release 8-director -d
EOF
if [ $? -eq 0 ]; then 
  sudo yum install -y http://rhos-release.virt.bos.redhat.com/repos/rhos-release/rhos-release-latest.noarch.rpm
  if [ $? -eq 0 ]; then
    sudo rhos-release -P 8-director -d
    if [ $? -eq 0 ]; then
      sudo yum update -y
      if [ $? -eq 0 ]; then
        source /home/stack/stackrc
        openstack undercloud upgrade
        if [ $? -eq 0 ]; then
          sudo yum install unzip -y
          if [ $? -eq 0 ]; then
            patch_code
            if [ $? -eq 0 ]; then
              rc=0
            fi
          fi
        fi
      fi
    fi
  fi
fi

exit $rc

