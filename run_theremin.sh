#!/bin/bash

# you probably need to modify these 
export HOMEDIR=/home/ben/theremin_remote
export JRUBY_PATH=/usr/share/rvm/rubies/jruby-9.2.0.0/bin/

cd $HOMEDIR
./disable_devices.sh # you can remove this if you correctly update your Xorg.conf
$JRUBY_PATH/jruby ./theremin_remote.rb
