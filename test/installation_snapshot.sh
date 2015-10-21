#!/bin/bash

set -e -x

snapper list | grep "after installation" && echo "AUTOYAST OK"
