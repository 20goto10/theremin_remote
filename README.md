# HAKeyboardRemote
Configurable Ruby script that allows Linux users to use an extra mouse and/or keyboard as a remote control and dimmer switch, mainly for home automation. 

This is a work in progress. The purpose was to take a $15 miniature keyboard-and-trackpad combo, tie it into HA-Bridge and OpenHAB2, and mount it on the wall near my front door to control all my "smart lights" from one place without having to talk out loud to my furniture (e.g. Alexa). I also wanted to use the mini-keyboard's built-in trackpad as a color selector for my entire apartment, which consists of various different brands of lights (hence the need for HA-Bridge and OpenHAB2 et al.).

Working:
- button mapping
- curl commands issued to HA-Bridge
- using Trackpad to control XY-colorspace 

Not working: 
- mouse buttons (wouldn't be hard to set up)

Roadmap:
- more Curl options (the commands for controlling a stereo, for example)
- toggles and multi-switches (e.g. check the state before sending the command)
- option to allow range shifts of color (so your colors can be subtly different)
- scenes and what-not
- whatever other improvements I think of
- set up as a service 
- instructions for keeping the input devices from doing stuff in X itself

Most such changes are trivial modifications to the Ruby code.

Contributing:
I'll be very happy if you submit PRs with more functionality to build off this base. It's not a complicated piece of code; I only wrote this because it didn't seem to exist already.

Prerequisites:
- You probably won't find much use for this without a wireless, external keyboard and/or mouse.
- You need to use jruby
- You need read permissions on the input device. You can either do this by running the script with sudo, or chmodding/chowning the input device permissions. 
 
```
gem install device_input
gem install json
gem install rest-client
```

Setup:
- Edit the config.json file. Mostly it should be self-explanatory. The most important thing is to get the device ID of your mouse and keyboard correctly, and the light IDs on HA-bridge. Depending on your set-up the username may need to change, and depending on your setup, the ha_bridge_url value. If you have the keyboard/mouse on the same machine that's running HA-Bridge you should be fine with "localhost". 
- Physically you'll want to check the range of your remote and make sure that whatever PC/Raspberry/etc. is running this script is within range of your remote keyboard and has connectivity to your ha-bridge server.
- You may also want to disable the surplus devices as actual X Inputs so that you can't accidentally run anything using the remote.


Run:

```
sudo ruby ruby_remote.rb
```
