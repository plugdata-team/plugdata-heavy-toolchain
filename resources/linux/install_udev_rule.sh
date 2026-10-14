#! /usr/bin/env bash
#
# Installs a udev rule so dfu-util can flash Daisy boards (STM32 DFU bootloader) without root.
# sudo asks for the password through askpass.sh, which also works without a terminal (e.g. from plugdata).
CURRENT_DIR=$(dirname -- "$( readlink -f -- "$0"; )"; )
export SUDO_ASKPASS=${CURRENT_DIR}/askpass.sh
echo 'SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="0666", GROUP="plugdev"' | sudo -A tee /etc/udev/rules.d/50-daisy-stmicro-dfu.rules> /dev/null
