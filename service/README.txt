- Edit theremin.service and ../run_theremin.sh to include the proper directory where you have installed Theremin Remote.
- If you are using X on the same server, you should probably disable the remote input devices in your Xorg configuration.
- If you are using a headless system (no X), you will probably need to remove the display-manager lines from the service file.

- Finally, run the following commands:
sudo cp theremin.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable theremin.service
sudo systemctl start theremin.service # although this should happen after reboot automatically, afterward

Note that it will take a little while to start up, and Openhab and/or HABridge will need to be running before it will actually do anything.
