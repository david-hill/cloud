#!/bin/bash

source functions
source_rc overcloudrc
rc=$?
if [ $rc -eq 0 ]; then
  test_overcloud
  rc=$?
fi

exit $rc
