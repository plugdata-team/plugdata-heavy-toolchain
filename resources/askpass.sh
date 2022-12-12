#! /usr/bin/env bash

PROMPT="Authentication required for $USER"

if which yad &>/dev/null; then
   exec yad --entry --entry-label "Password" --hide-text --image=password --window-icon=dialog-password --text="$PROMPT" --title=Authentication --center
    elif which zenity &>/dev/null; then
        exec zenity --password --title "$PROMPT"
    elif which kdialog &>/dev/null; then
     exec kdialog --title "Authentication" --password "$PROMPT"
    else
        STTY_SAVE="$(stty -g)"

        abort() {
        stty $STTY_SAVE
        }

        trap abort EXIT
        echo -n "Enter password for $USER: " > /dev/stderr
        stty -echo
        read PASSWORD
        echo
        stty $STTY_SAVE
    fi
