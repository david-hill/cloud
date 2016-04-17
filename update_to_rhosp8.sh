rc=255

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
          rc=$?
        fi
      fi
    fi
  fi
fi

exit $rc

