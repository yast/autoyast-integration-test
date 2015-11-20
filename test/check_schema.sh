#!/bin/bash
#
# Check the schema generated when cloning the installed system.
#
# * libxml2-tools will be installed (if it isn't already) to make xmllint
#   available.
# * The system won't be cloned, so /root/autoinst.xml should exist.
set -e -x

xmllint --noout --relaxng /usr/share/YaST2/schema/autoyast/rng/profile.rng \
  /root/autoinst.xml && echo "AUTOYAST OK"
