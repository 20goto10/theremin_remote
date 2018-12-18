# Theremin Remote (a.k.a. HAKeyboardRemote)
A simple system for converting input devices (e.g. mice, keyboards, etc.) into remote controls for issuing remote API requests. This is a configurable Ruby script that allows Linux users to use devices (presumably wireless) as dimmer switches or whatever else you might have in mind, mainly for home automation. 

The project is nicknamed "Theremin" because, as it stands now, you can use the touchpad to control home lights much the way a trained musician plays a theremin (except that you do have to touch the touchpad). Anyway, it maps the X & Y coordinates of the touchpad into the XY color space (aka CIE 1931), so you wind up with a sort of two-dimensional dimmer switch. The button controls are really just a bonus. 

This is a work in progress. The purpose was to take a $15 miniature keyboard-and-trackpad combo, tie it into HA-Bridge and OpenHAB2, and mount it on the wall near my front door to control all my "smart lights" from one place without having to talk out loud to my furniture (e.g. Alexa). I also wanted to use the mini-keyboard's built-in trackpad as a color selector for my entire apartment, which consists of various different brands of lights (a major factor in the need for HA-Bridge and OpenHAB2 et al.).

Working:
- button mapping
- curl commands issued to HA-Bridge
- using Trackpad to control XY-colorspace 
- color randomization and rotation
- multiple input devices

Not working: 
- mouse buttons (wouldn't be hard to set up)

Roadmap:
- more Curl options (the commands for controlling a stereo, for example)
- toggles (e.g. check the state before sending the command)
- multi-switch toggles 
- scenes and what-not
- whatever other improvements I think of
- instructions/files for setting this up as a service
- fun programming routines for the lights (make 'em dance)

Most such changes are trivial modifications to the Ruby code.

Contributing:
I'll be very happy if you submit PRs with more functionality to build off this base. It's not a complicated piece of code; I only wrote this because it didn't seem to exist already.

Prerequisites:
- You probably won't find much use for this without an external keyboard and/or mouse. As for me, I'm going to set up some wireless-USB "retro gaming" SNES controllers as light switches. 
- You might need a rudimentary understanding of the /dev/input devices and input event handling in a linux environment. Well honestly, you can probably figure most of what you need using my config.json as an example.
- I have no idea if this will work in non-Linux environment... it would probably work on a Mac, but I doubt it would work under Windows.
- You need to use Jruby, not regular Ruby, since it is required by Manticore, the underlying API request library (chosen for speed).
- You need read permissions on the input device. You can either do this by running the script as root (sudo ruby theremin.rb), or chmodding/chowning the input device permissions. Note if you do the latter that the device permissions will be reset at reboot or whenever you unplug/replug the input device. 
 
```
gem install manticore
gem install device_input
gem install json
```

Update the config.json before you run the script. Light IDs should correspond to those in your HA-Bridge. 

I've included a script, disable_devices.sh, for disabling Xinputs (note that you must modify it as your DEVICE string is probably different; to figure it out, try ```DISPLAY=:0 xinput list```). In my case, all the devices come up as "2.4G Composite Devic" [sic] ... that's what comes up for at least two different makes of these cheapo mini-keyboards, so it might be pretty common. 

```
#!/bin/bash
DEVICE_TO_DISABLE="2.4G Composite Devic"
DEVICES=`DISPLAY=:0 xinput list | grep "$DEVICE_TO_DISABLE" | sed 's/^.*id=//g' | cut -f1`
for i in $DEVICES
do
  echo Disabling X input from device $i
  DISPLAY=:0 xinput disable $i
done
```

Setup:
- Edit the config.json file. Mostly it should be self-explanatory. The most important thing is to get the device ID of your mouse and keyboard correctly, and the light IDs on HA-bridge. Depending on your set-up the username may need to change, and depending on your setup, the ha_bridge_url value. If you have the keyboard/mouse on the same machine that's running HA-Bridge you should be fine with "localhost". 
- Physically you'll want to check the range of your remote and make sure that whatever PC/Raspberry/etc. is running this script is within range of your remote keyboard and has connectivity to your ha-bridge server.
- You will probably also want to disable the surplus devices as actual X Inputs so that you can't accidentally do something crazy using the remote. Or you could just not run X11 in the first place. Disable the Xinputs is pretty straightforward.


Run:

```
ruby theremin.rb # you may need sudo if you haven't changed your device permissions
```

