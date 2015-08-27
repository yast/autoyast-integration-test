#!/bin/bash

set -e -x

grep "FW_CONFIGURATIONS_EXT=\"apache2 apache2-ssl\"" /etc/sysconfig/SuSEfirewall2
echo "AUTOYAST OK"
