#!/bin/bash

# NOTE - This loops over a list of admin users and resets their passwords in WordPress
for USER in $(cat ~/administrator-user.txt)
do
    echo "Generating Password for $USER"
    COOLPASSWD=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
    #1 second delay between generating passwords required
    sleep 1
    #change password
    wp user update $USER --user_pass=$COOLPASSWD
    echo "$USER -> $COOLPASSWD" >> ~/administrator-passwords.txt
done
