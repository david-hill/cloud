import yaml
import sys

file=sys.argv[1]

print(file)
with open(file, 'r') as stream:
    try:
        yaml.load(stream)
    except yaml.YAMLError as exc:
        print(exc)

