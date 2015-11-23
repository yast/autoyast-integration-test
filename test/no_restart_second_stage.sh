#!/bin/bash

set -e -x

# bug 956043 - YAST second stage must not restarted while activating

grep "Skipping service YaST2-Second-Stage - it's already in desired state" /var/log/YaST2/y2log && echo "AUTOYAST OK"
