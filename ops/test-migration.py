from novaclient import client as nova_client
from novaclient.v2.contrib import instance_action
from novaclient import extension
from keystoneauth1.identity import v3
from keystoneauth1 import session as ksession
from osc_lib import utils
from pprint import pprint
import time
import sys
import dateutil.parser as parser

debug=0
cl_nova=None

def test_migrate(vm,hyps):
     if debug:
       pprint(vars(vm))

     try:
       orig_host=vm.host
     except:
       orig_host=vm._info.get('OS-EXT-SRV-ATTR:host')

     migration_timeout=300

     def print_migr_details(vm):
	 ai=cl_nova.instance_action.list(vm.id)
	 a=sorted(ai,key=lambda x:x.start_time)[-1]
	 details=cl_nova.instance_action.get(vm.id,a.request_id)
	 for d in sorted(details.events,key=lambda x:x['start_time']):
	      start=int(parser.parse(d['start_time']).replace(tzinfo=None).strftime("%s"))-14400
	      finish=int(parser.parse(d['finish_time']).replace(tzinfo=None).strftime("%s"))-14400
	      print "  %10s -> %10s %45s" %( start, finish, d['event'] )

     def wait_for_migration(vm,target):
	 for i in xrange(1, migration_timeout):
	     vm = cl_nova.servers.get(vm.id)
	     if getattr(vm, 'OS-EXT-SRV-ATTR:hypervisor_hostname') == target: # noqa
	         print_migr_details(vm)
	         print '[%s] Live-migation of %s has finished' % (time.time(),vm.id)
	         break
	     if vm.status in ('ACTIVE','ERROR'):
	         print '[%s] Live-migation of %s has failed' % (time.time(),vm.id)
	         return 1
	     time.sleep(5)
	 else:
	     print 'Unable to live migrate %s until timeout %s' % (
	         vm.id, migration_timeout)
	     return 1
	 return 0

     for h in hyps:
	 target_host=h.hypervisor_hostname
         if target_host == orig_host:
             continue
	 print "[%s] Migrate to %s" % (time.time(),target_host)
	 if h.state=='up':
	     cl_nova.servers.live_migrate(vm.id, target_host, True, True)
	 wait_for_migration(vm,target_host)
	 time.sleep(5)

auth_url=utils.env('OS_AUTH_URL')
username=utils.env('OS_USERNAME')
password=utils.env('OS_PASSWORD')
domain=utils.env('OS_USER_DOMAIN_NAME')
project=utils.env('OS_PROJECT_DOMAIN_NAME')
project_name=utils.env('OS_PROJECT_NAME')

_auth = v3.Password(
	        auth_url=auth_url,
	        username=username,
	        password=password,
	        user_domain_name=domain,
	        project_domain_name=domain,
	        project_name=project_name
	    )
_session = ksession.Session(_auth)
nova_extensions = [
	extension.Extension(
	    instance_action.__name__.split(".")[-1],
	    instance_action
	),
    ]
cl_nova=nova_client.Client(
	        '2', session=_session,
	        extensions=nova_extensions
)

hyps=cl_nova.hypervisors.list()
vm=cl_nova.servers.get(sys.argv[1])
test_migrate(vm,hyps)
