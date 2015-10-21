#!/bin/bash

set -e -x
gunzip /var/log/YaST2/y2log-1.gz
# Checking it ntp sync has been passed
grep "NTP syncing with" /var/log/YaST2/y2log-1 && echo "AUTOYAST OK"
