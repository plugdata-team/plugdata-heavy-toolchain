#! /usr/bin/env bash
#
# sudo-askpass - Use yad or zenity to ask for sudo password
#
# To use, add this to your shell profile:
#
# export SUDO_ASKPASS=sudo-askpass
#
# and then call sudo with the "-A" option

export SUDO_ASKPASS=askpass.sh
echo 'SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="0666", GROUP="plugdev"' | sudo -A tee /etc/udev/rules.d/50-daisy-stmicro-dfu.rules> /dev/null


