# HAKeyboardRemote
Configurable Ruby script that allows Linux users to use an extra mouse and/or keyboard as a remote control and dimmer switch, mainly for home automation. 

This is a work in progress. The purpose was to take a $15 miniature keyboard-and-trackpad combo, tie it into HA-Bridge and OpenHAB2, and mount it on the wall near my front door to control all my "smart lights" from one place without having to talk out loud to my furniture (e.g. Alexa). I also wanted to use the mini-keyboard's built-in trackpad as a color selector for my entire apartment, which consists of various different brands of lights (hence the need for HA-Bridge and OpenHAB2 et al.).

Working:
- button mapping
- curl commands issued to HA-Bridge
- using Trackpad to control XY-colorspace 

Not working: 
- mouse buttons (whouldn't be hard to set up)

Roadmap:
- whatever improvements I think of

Preqrequisites:
- You probably won't find much use for this without a wireless, external keyboard and/or mouse.
 
```
gem install device_input
gem install json
gem install rest-client
```

Setup:
- Edit the config.json file. Mostly it should be self-explanatory. The most important thing is to get the device ID of your mouse and keyboard correctly, and the light IDs on HA-bridge. Depending on your set-up the username may need to change.  

Run:

```
sudo ruby ruby_remote.rb
```
