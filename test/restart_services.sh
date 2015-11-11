#!/bin/bash

set -e -x
# checking if dbus and all wickedd services has not been restarted
# bnc#944349

grep "restarting services" y2log| grep -v 'dbus.service\|wickedd' && echo "AUTOYAST OK"
