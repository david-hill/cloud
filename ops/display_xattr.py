import os
import xattr

debug = 0
directory = '/srv'
stringtoskip = "security.selinux"

def recurse_directory( directory ):
  for filename in os.listdir(directory):
    if os.path.isdir(directory + "/" + filename):
      if debug:
        print("%s is a folder" % filename)
      recurse_directory(directory + "/" + filename)
    for p in xattr.listxattr(directory + "/" + filename):
      s=str(p)
      if s.find(stringtoskip) != 2:
        print(s.find(stringtoskip))
        print("%s : %s" % ( directory + "/" + filename, p ) )

recurse_directory(directory)

