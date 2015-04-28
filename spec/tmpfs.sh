#!/bin/bash

set -e -x

NO_TMP_DEVICE=1

# Checking if there is no tmpfs device defined
grep "<device>/dev/tmpfs</device>" /root/autoinst.xml && NO_TMP_DEVICE=0

test $NO_TMP_DEVICE -eq 1 && echo "AUTOYAST OK"
