# Theremin Remote (a.k.a. HAKeyboardRemote)
A simple system for using HID (human input devices, e.g. mice, keyboards, etc.) as remote controls for issuing remote API requests. This is a configurable Ruby script that allows Linux users to use devices (presumably wireless) as dimmer switches or whatever else you might have in mind, mainly for home automation. 

The project is nicknamed "Theremin" because, as it stands now, you can use the touchpad to control home lights much the way a trained musician plays a theremin (except that you do have to touch the touchpad). Anyway, it maps the X & Y coordinates of the touchpad into the HSL or XY color space (aka CIE 1931), so you wind up with a sort of two-dimensional dimmer switch. Actually using the thing this way is kind of a nightmare so just use the buttons.

This is a work in progress. The purpose was to take a $15 miniature keyboard-and-trackpad combo, tie it into HA-Bridge and/or OpenHAB2, and mount it on the wall near my front door to control all my "smart lights" from one place without having to talk out loud to my furniture (e.g. Alexa). I also wanted to use the mini-keyboard's built-in trackpad as a color selector for my entire apartment, which consists of various different brands of lights (a major factor in the need for HA-Bridge and OpenHAB2 et al.). So I've mounted the controller by my door using magnets (so I can easily remove it to use on the couch, or recharge it) and now I can turn everything on or off when I leave or enter my apartment.

## Working:
- button mapping
- curl commands issued to HA-Bridge or Openhab
- using Trackpad to control XY-colorspace 
- color randomization and rotation
- multiple input devices
- direct connection support for HA-bridge or directly to OpenHAB2 (the second seems faster, more reliable, and generally more color-intense!)
- custom request/toggle commands (acting against a received state) - this is a little primitive for now, but works ok with Openhab
- arbitrary commands ("exec" -- I use this to run [advanced eISCP commands via Python](https://github.com/miracle2k/onkyo-eiscp) on my Onkyo stereo, e.g. for FM and Internet Radio presets, since OpenHAB is not supporting them yet)

## Security warning:
- The "exec" and "eval" commands in my config script could allow arbitrary code execution if for some weird reason you were to run a config file you didn't write yourself. I can't imagine anyone doing that, but thought I should mention it.

## Roadmap:
- user guide (if people are actually interested in Theremin Remote at all)
- scenes and what-not
- whatever other improvements I think of
- fun programming routines for the lights (make 'em dance)

Most such changes are trivial modifications to the Ruby code.

## Contributing:
I'll be very happy if you submit PRs with more functionality to build off this base. It's not a complicated piece of code; I only wrote this because it didn't seem to exist already.

## Prerequisites:
- You probably won't find much use for this without at least one external keyboard and/or mouse. 
- You might need a rudimentary understanding of the /dev/input devices and input event handling in a linux environment. Well honestly, you can probably figure most of what you need using my config.json as an example.
- I have no idea if this will work in non-Linux environment... it would probably work on a Mac, but I doubt it would work under Windows. It has been tested very successfully using OpenHABian on a Raspberry Pi Model 3 B.
- You need some sort of target for the requests. My code is based on a modified HA-Bridge-- modified in that I added HSL colorspace support, which HA-Bridge is supposed to pass onto OpenHAB. At the time of this writing it is an open pull request at ha-bridge, awaiting review... You can just pull it in and compile it locally. https://github.com/bwssytems/ha-bridge/pull/1028 and then you can use ${color.hsl} in your colorization requests to HA-Bridge. HOWEVER, as of 12/19/2018 I've added support for OpenHAB2 directly (though it is a work-in-progress) which seems better overall, and obviates any need for the CIE 1931 / a.k.a. XY colorspace which is just a nightmare to handle anyway.

## Suggested hardware:
- [Mitid Wireless Mini Keyboard](https://www.amazon.com/Mitid-Wireless-Keyboard-Touchpad-Raspberry/dp/B01E565PIQ/ref=as_li_ss_tl?ie=UTF8&tag=skullbasher-20&linkCode=as2&camp=217145&creative=399373&creativeASIN=1608870243) - I suggest this one because it appears to have a nice HSL bar printed right on it. I don't actually have this one; mine is made by Inland and has a few more buttons and back lighting. Any keyboard and/or mouse should work (they do not have to be wireless).
- Some cheap computer/Raspberry Pi/whatever that can handle OpenHAB and/or HA-Bridge for running the remote listener.

## Ruby and Ruby Prerequisites: 
You will need to install Ruby 2.0 or greater and the ruby2.3-dev and libcurl-dev libs:
```
sudo apt-get install ruby2.3 ruby2.3-dev libcurl4-openssl-dev
```
then:
```
gem install curb
gem install ffi
gem install device_input
gem install json
```

Copy the config.json.example to config.json, and modify it to your Openhab2 and/or HABridge settings before you run the script. The mode option must be 'openhab', anything else is currently treated as 'ha_bridge'. If using the ha_bridge mode, light IDs should correspond to those in your HA-Bridge. Otherwise you must also set mappings for the lights in the section called 'openhab_devices' to correspond to the IDs for your commands. Someday maybe I will add a GUI.

## A bit of miscellany:
- I've included a simple script, internet_radio_preset.sh, which simply writes a counter so you can step through internet radio presets on devices that don't support it (e.g. the Onkyo NR-626). It is really somewhat out-of-scope for this project, but it hardly merits its own repo either. If you have an Onkyo receiver you can use this with [onkyo-eiscp](https://github.com/miracle2k/onkyo-eiscp).

## Setup:
- Copy the config.json.example file to config.json. Mostly it should be self-explanatory. The most important thing is to get the device ID of your mouse and keyboard correctly, and the light IDs on HA-bridge. Depending on your set-up the username may need to change, and depending on your setup, the ha_bridge_url value. If you have the keyboard/mouse on the same machine that's running HA-Bridge you should be fine with "localhost". 
- Your results will probably be screwy if you include switches instead of color bulbs in commands that rely on color (e.g. random, rotate, and the like), or color assignments to dimmer lights. 
- Physically you'll want to check the range of your remote and make sure that whatever PC/Raspberry/etc. is running this script is within range of your remote keyboard and has connectivity to your ha-bridge server.
- Choose a "mode" value in your config.json. The options are "openhab" and "ha_bridge". In "openhab" mode, you must define device IDs in the openhab_devices section of the config.json. In "ha_bridge" mode the IDs are the ones ha_bridge itself uses, so it's somewhat simpler to set up the config (though setting up HA_Bridge itself is an equal chore). Openhab mode is slightly faster since it eliminates the middleman, and it lets you use HSL colors which are much easier to work with than that whole XY/CIE1931 thing. But since I started coding this through ha_bridge before realizing any of that, I've left both modes available.

## Run:

```
ruby theremin.rb 
```


