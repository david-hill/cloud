#!/usr/bin/python

import requests
import MySQLdb
from oslo_serialization import jsonutils

# Open database connection
db = MySQLdb.connect("localhost","root","","heat" )
cursor = db.cursor()
cursor.execute("select rsrc_metadata, p.value from resource as r, resource_data as p where p.value like '%ov-qgmvqezkze%' and r.id=p.resource_id;")
results = cursor.fetchall()
for row in results:
   metadata = row[0]
   url = row[1]
#   json_md = jsonutils.dumps(metadata)
   print "metadata=%s url=%s"% ( metadata, url )
   resp = requests.put(url, metadata)
   resp.raise_for_status()
db.close()
