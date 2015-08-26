#!/bin/bash
set -x

# Check it handles correctly multiple kdump crash_kernel options

grep "crashkernel=72M,low crashkernel=32M,high" /boot/grub2/grub.cfg && echo "AUTOYAST OK"
