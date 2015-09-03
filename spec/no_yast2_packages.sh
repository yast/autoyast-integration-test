#!/bin/bash
set -x

# Check if AutoYaST2 packages were installed.
rpm -qi yast2 || echo "AUTOYAST OK"
