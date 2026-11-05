#!/bin/bash
# Run at Hyprland login. Starts the root-owned weekly snapshot service.
# A sudoers rule (/etc/sudoers.d/weekly-snapshot) allows exactly this command without a password.
sudo -n /usr/bin/systemctl start --no-block weekly-snapshot.service
