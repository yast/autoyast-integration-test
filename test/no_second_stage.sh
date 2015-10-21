#!/bin/bash

# Check if the second stage was skipped
grep "Stage \[2\]" /var/log/YaST2/y2start.log || echo "AUTOYAST OK"
