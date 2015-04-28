#!/bin/bash

set -e -x

GERMAN_KEYBOARD=0

# Checking if german keybaord has been set due german language setting
grep "<keymap>german</keymap>" /root/autoinst.xml && GERMAN_KEYBOARD=1

test $GERMAN_KEYBOARD -eq 1 && echo "AUTOYAST OK"
