#!/bin/bash 
cd /usr/lib/python3.6/site-packages/ironicclient
/usr/bin/patch -p2 < /tmp/patch
