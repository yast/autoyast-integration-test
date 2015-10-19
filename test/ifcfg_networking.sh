#!/bin/bash

set -e -x

# bsc#949193
# Expect the network configuration to correspond to the XML profile.
# The installation-time network setup has a plain STARTMODE=auto
# so we check for the STARTMODE specified in XML <networking> element.
grep "^STARTMODE.*nfsroot" /etc/sysconfig/network/ifcfg-eth0 && echo "AUTOYAST OK"
