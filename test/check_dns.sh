#!/bin/bash

set -e -x

grep "nameserver 10.10.0.100" /etc/resolv.conf && echo "AUTOYAST OK"
