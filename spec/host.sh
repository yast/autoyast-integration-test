#!/bin/bash

set -e -x

grep "10.226.154.19   new.entry.de h999uz" /etc/hosts && echo "AUTOYAST OK"
