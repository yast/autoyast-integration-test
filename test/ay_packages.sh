#!/bin/bash

set -e -x

# Checking if needed packages are available which have been described
# in the AY file. (bnc#955657)

rpm -q yast2-printer yast2-kdump yast2-nis-client yast2-ntp-client && echo "AUTOYAST OK"

