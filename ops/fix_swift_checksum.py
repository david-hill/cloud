import os
import xattr
import hashlib
import re

debug = 1
directory = '/srv'
stringtoskip = 'security.selinux'
matchchecksum = 'user.swift.metadata$'
re.compile(matchchecksum)

def recurse_directory( directory ):
  for filename in os.listdir(directory):
    if os.path.isdir(directory + "/" + filename):
      if debug:
        print("%s is a folder" % filename)
      recurse_directory(directory + "/" + filename)
    for p in xattr.listxattr(directory + "/" + filename):
      s=p.decode()
      if s.find(stringtoskip) != 2:
        print(s.find(stringtoskip))
        print("= %s : %s" % ( directory + "/" + filename, p ) )
        print("%s", xattr.get(directory + "/" + filename,p))
        if re.search(matchchecksum, s):
          try:
            thisxattr=xattr.get(directory + "/" + filename, 'user.swift.metadata_checksum')
          except:
            thisxattr=''
          try:
            if not thisxattr:
              new_checksum = hashlib.md5(xattr.get(directory + "/" + filename,p)).hexdigest()
              print("SET CHKSUM: %s" % ( new_checksum ))
              xattr.set(directory + "/" + filename, 'user.swift.metadata_checksum', new_checksum)
            else:
              if debug:
                new_checksum = hashlib.md5(xattr.get(directory + "/" + filename,p)).hexdigest()
                print("CHKSUM: %s %s" % (xattr.get(directory + "/" + filename, 'user.swift.metadata_checksum'), new_checksum))
          except:
            raise
        else:
          print("%s didn't match %s" % ( matchchecksum, s ))

recurse_directory(directory)
