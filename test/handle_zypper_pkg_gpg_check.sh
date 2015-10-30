#!/bin/bash

set -e -x
zgrep "PkgGpgCheck" /var/log/YaST2/y2log && echo "AUTOYAST OK"
