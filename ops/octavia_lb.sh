#!/bin/bash
# (Initially) Written by Albert Cardenas

### source env variables
if [ -r /root/openrc ] ; then
    # Ubuntu/OpenStack customer cloud credentials
    source /root/openrc
elif [ -r /etc/redhat-release ] ; then
    # Red Hat OSP customer cloud credentials
    source ~stack/stackrc
    source ~stack/$(openstack stack list -f value -c 'Stack Name')rc
else
    echo "ERROR: Unable to find customer cloud rc file"
    exit 2
fi

echo
echo '=================================='
echo 'USER-INPUT THE LOADBALANCER ID'
echo '=================================='
echo -n "LOADBALANCER ID: "
read LOADBALANCER_ID
echo 
echo 
echo 

echo '=================================='
echo 'LOADBALANCER INFO'
echo '=================================='
openstack loadbalancer show $LOADBALANCER_ID
echo

echo '=================================='
echo 'LOADBALANCER AMPHORA/OPENSTACK_VM INFO'
echo '=================================='
echo 'INFO: amphora is a fancy name for haproxy living inside an Openstack VM'
echo
echo 'Openstack LB Amphora:'
openstack loadbalancer amphora list --loadbalancer $LOADBALANCER_ID
echo
echo 'Associated Openstack VM(s):'
for AMPHORA_ID in `openstack loadbalancer amphora list --loadbalancer $LOADBALANCER_ID -c id -f value`; do openstack server list --all --name amphora-${AMPHORA_ID}; echo ; done
echo

echo '=================================='
echo 'LOADBALANCER POOL INFO'
echo '=================================='
for POOL_ID in `openstack loadbalancer pool list --loadbalancer $LOADBALANCER_ID -c id -f value`; do echo 'POOL ID: ' $POOL_ID; openstack loadbalancer pool show $POOL_ID; echo; done
echo

echo '=================================='
echo 'LOADBALANCER MEMBER INFO (K8s VMs like worker/master/etcd)'
echo '=================================='
for POOL_ID_MEMBER in `openstack loadbalancer pool list --loadbalancer $LOADBALANCER_ID -c id -f value`; do echo 'POOL ID: ' $POOL_ID_MEMBER; openstack loadbalancer member list $POOL_ID_MEMBER; echo ; done
echo
echo 'INFO: All VM(s) in LBs project'
for PROJECT in `openstack loadbalancer show $LOADBALANCER_ID -c project_id -f value`; do openstack server list --project $PROJECT -c ID -c Name -c Networks; done
echo 

echo '=================================='
echo 'LOADBALANCER LISTENER INFO'
echo '=================================='
for LISTENER_ID in `openstack loadbalancer listener list --loadbalancer $LOADBALANCER_ID -c id -f value`; do echo 'LISTENER ID: ' $LISTENER_ID; openstack loadbalancer listener show $LISTENER_ID; echo ; done
echo 
echo
echo
echo

echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! DISCLAIMER !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!! IF YOUR LOADBALANCER CANT BE DELETED DUE TO 'provisioning_status' THEN YOU   !!"
echo "!!  NEED TO RUN THE FOLLOWING COMMANDS TO UPDATE THE DATABASE AND DELETE THE    !!"
echo "!!                        LOADBALANCER. BE EXTRA CAREFUL                        !!"
echo "!!                                                                              !!"
echo "!!  # mysql octavia                                                             !!"
echo "!!  > update load_balancer set provisioning_status='ACTIVE' where id='<LB_ID>'; !!"
echo "!!  # openstack loadbalancer delete <LB_ID> --cascade                           !!"
echo "!!                                                                              !!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
