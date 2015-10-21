#!/bin/bash

set -e -x

getent passwd|grep "root:x:0:0:root:/root:/bin/bash"  && echo "AUTOYAST OK"
