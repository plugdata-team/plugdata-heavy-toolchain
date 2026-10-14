#! /usr/bin/env bash
#
# SUDO_ASKPASS helper: asks for the password in a dialog, or on the terminal as a fallback.
# sudo -A reads the password from stdout, so prompts go to stderr.

PROMPT="Authentication required for $USER"

if which yad &>/dev/null; then
    exec yad --entry --entry-label "Password" --hide-text --image=password --window-icon=dialog-password --text="$PROMPT" --title=Authentication --center
elif which zenity &>/dev/null; then
    exec zenity --password --title "$PROMPT"
elif which kdialog &>/dev/null; then
    exec kdialog --title "Authentication" --password "$PROMPT"
else
    STTY_SAVE="$(stty -g)"
    trap 'stty $STTY_SAVE' EXIT
    echo -n "Enter password for $USER: " > /dev/stderr
    stty -echo
    read -r PASSWORD
    echo > /dev/stderr
    printf '%s\n' "$PASSWORD"
fi
