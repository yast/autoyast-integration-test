#!/bin/bash

set -e -x

SUBVOLUMES=0
NO_SUBVOLUME_SYN=1

# Checking for subvolumes
grep "<subvolumes config:type=\"list\">" /root/autoinst.xml && SUBVOLUMES=1
grep "<listentry>@</listentry>" /root/autoinst.xml && NO_SUBVOLUME_SYN=0

test $SUBVOLUMES -eq 1 -a $NO_SUBVOLUME_SYN -eq 1 && echo "AUTOYAST OK"
