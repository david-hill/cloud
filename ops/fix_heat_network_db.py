import pymysql
import argparse

names = ['InternalApiNetwork', 'StorageNetwork', 'TenantNetwork',
        'ExternalNetwork', 'StorageMgmtNetwork',
        'ExternalSubnet', 'StorageMgmtSubnet', 'InternalApiSubnet',
        'TenantSubnet', 'StorageSubnet']

def main():

    parser=argparse.ArgumentParser()
    parser.add_argument('--version', help='Director Version')
    version = int(parser.parse_args().version)

    connection = pymysql.connect(read_default_file='/root/.my.cnf', db='heat')

    # Had some issues with the above, so I had to use rather this:
    # connection = pymysql.connect(unix_socket='<path_to_mysql_socket>', user='root', password='<mysql_root_pass>', db='heat')
    try:
        with connection.cursor() as cursor:
            if version < 11:
                select = 'SELECT id, nova_instance, action, status, stack_id, properties_data FROM resource WHERE name=%s'
            else:
                select = 'SELECT id, nova_instance, action, status, stack_id, rsrc_prop_data_id FROM resource WHERE name=%s'
            for name in names:
                cursor.execute(select, (name,))
                new = old = None
                for row in cursor.fetchall():
                    if row[1] is None:
                        if row[2] == 'CREATE' and row[3] == 'FAILED':
                            new = row
                            continue
                        if row[2] == 'INIT' and row[3] == 'COMPLETE':
                            new = row
                            continue
                    if row[1] is not None:
                        if row[2] == 'CREATE' and row[3] == 'COMPLETE':
                            old = row
                            continue
                        if row[2] == 'DELETE' and row[3] == 'FAILED':
                            old = row
                            continue
                if not new or not old:
                    print "# Nothing for %s" % name
                else:
                    print "# Update for %s" % name
                    print "DELETE FROM resource WHERE id={};".format(old[0])
                    if version < 11:
                        print "UPDATE resource SET action='CREATE', status='COMPLETE', nova_instance='{}', properties_data='{}'  WHERE id={};".format(
                            old[1], old[5], new[0])
                    else:
                        print "UPDATE resource SET action='CREATE', status='COMPLETE', nova_instance='{}', rsrc_prop_data_id={}  WHERE id={};".format(
                            old[1], old[5], new[0])

    finally:
        connection.close()

if __name__ == "__main__":
    main()
