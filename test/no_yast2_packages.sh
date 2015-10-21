#!/bin/bash
set -x

# Check that YaST2 packages were not installed.
rpm -qi yast2 || echo "AUTOYAST OK"
