#!/bin/bash
# Script for stepping through Internet radio presets (or any similar counter) on an Onkyo-626 which does not have this functionality.
# MAX should be set to the highest number preset you have, and MIN should probably be 1.  
FILENAME=internet_radio_preset.txt
MAX=32
MIN=1

if [ -e $FILENAME ]
then
  CURRENT_VALUE=`cat $FILENAME`
else
  CURRENT_VALUE=0
fi
  
if [ " $1" == " down" ]
then
  let CURRENT_VALUE=$(($CURRENT_VALUE - 1))
else
  let CURRENT_VALUE=$(($CURRENT_VALUE + 1))
fi

re='^ [0-9]+$'
if [[ " $1" =~ $re ]] ; then
   let CURRENT_VALUE=$1
fi

if [ $CURRENT_VALUE -lt $MIN ]
then
  let CURRENT_VALUE=$MAX
fi

if [ $CURRENT_VALUE -gt $MAX ]
then
  let CURRENT_VALUE=$MIN
fi

echo $CURRENT_VALUE > $FILENAME
echo `printf '%02x\n' $CURRENT_VALUE` # because the Onkyo requires hex digits for some reason
