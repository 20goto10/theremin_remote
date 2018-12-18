#!/bin/bash
DEVICE_TO_DISABLE="2.4G Composite Devic"
DEVICES=`DISPLAY=:0 xinput list | grep "$DEVICE_TO_DISABLE" | sed 's/^.*id=//g' | cut -f1`
for i in $DEVICES
do
  echo Disabling X input from device $i
  DISPLAY=:0 xinput disable $i
done
