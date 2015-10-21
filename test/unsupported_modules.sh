#!/bin/bash

set -e -x
grep "Could not process these unsupported profile sections: \[\"autofs\", \"restore\", \"sshd\"\]"\
 /var/log/YaST2/y2log && echo "AUTOYAST OK"
