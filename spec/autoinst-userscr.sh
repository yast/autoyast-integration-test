#!/bin/bash

set -e -x
LOGFILE='/root/userscripts/userscr.log'
RESULT=`cat $LOGFILE | sed -r -e s'@\:.*\:@:@' | tr '\n' '|'`
EXPECTED='1:clean|1b:ok|2:ok|3:ok|4:ok|5:ok|'

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

if [ "$RESULT" == "$EXPECTED" ];then 
  echo "AUTOYAST OK"
else
  echo "USERSCRIPTS FAILURE DETECTED "
fi
	
