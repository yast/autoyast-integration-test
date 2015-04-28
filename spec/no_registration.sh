#!/bin/bash

set -e -x

NO_REGISTRATION=1

# Checking if registration data will not be created with clone_system
grep "<suse_register>" /root/autoinst.xml && NO_REGISTRATION=0

test $NO_REGISTRATION -eq 1 && echo "AUTOYAST OK"
