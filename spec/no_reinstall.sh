#!/bin/bash

set -e -x

! grep "job: install bind" y2log && echo "AUTOYAST OK"
