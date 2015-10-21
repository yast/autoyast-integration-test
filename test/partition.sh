#!/bin/bash

set -e -x

PARTITION_1=0
PARTITION_2=0

# Checking for the right partition_nr
grep "<partition_nr config:type=\"integer\">1</partition_nr>" /root/autoinst.xml && PARTITION_1=1
grep "<partition_nr config:type=\"integer\">2</partition_nr>" /root/autoinst.xml && PARTITION_2=1

test $PARTITION_1 -eq 1 -a $PARTITION_2 -eq 1 && echo "AUTOYAST OK"
