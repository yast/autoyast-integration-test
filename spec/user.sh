#!/bin/bash

set -e -x

getent passwd|grep "vagrant:x:1000:100:vagrant:/home/vagrant:/bin/bash" && echo "AUTOYAST OK"
