source ~/stackrc
WORKFLOW='tripleo.storage.v1.ceph-install'
UUID=$(mistral execution-list --limit=-1 | grep $WORKFLOW | awk {'print $2'} | tail -1)
for TASK_ID in $(mistral task-list $UUID | awk {'print $2'} | egrep -v 'ID|^$'); do
    echo $TASK_ID
    mistral task-get $TASK_ID
done
