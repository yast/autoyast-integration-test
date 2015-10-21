#!/bin/bash

set -e -x

grep "<peers config:type=\"list\">" /root/autoinst.xml
grep "<peer>" /root/autoinst.xml
grep "<restricts config:type=\"list\">" /root/autoinst.xml
grep "<restrict>" /root/autoinst.xml
echo "AUTOYAST OK"
