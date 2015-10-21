#!/bin/bash

set -e -x
LOGFILE='/root/userscripts/userscr.log'
RESULT=`cat $LOGFILE | sed -r -e s'@\:.*\:@:@' | tr '\n' '|'`
RET="AUTOYAST OK"
EXPECTED='1:clean|1b:ok|2:ok|3:ok|5:ok|'

set -e +x

echo 
echo "result log:"
echo "test number:phase:message:result"
echo "-------------------------------------"
cat $LOGFILE

echo 
echo 
echo "expected test runs and results:"
echo "-------------------------------------"
echo $EXPECTED | tr '|' '\n' 

echo "$RESULT" | grep -v '1:clean' && RET="USERSCRIPTS FAILURE DETECTED 1"
echo "$RESULT" | grep -v '1b:ok' && RET="USERSCRIPTS FAILURE DETECTED 1b"
echo "$RESULT" | grep -v '2:ok' && RET="USERSCRIPTS FAILURE DETECTED 2"
echo "$RESULT" | grep -v '3:ok' && RET="USERSCRIPTS FAILURE DETECTED 3"
echo "$RESULT" | grep -v '5:ok' && RET="USERSCRIPTS FAILURE DETECTED 5"

echo "$RET"
