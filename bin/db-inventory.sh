#!/bin/bash

# NOTE - This loops over a list of config paths and outputs the credentials
USERNAME=$(whoami)
CONFIG_PATH_NAME="config-paths.txt"
DB_CREDS_NAME="db-credentials_$(date '+%F').txt"
CONFIG_PATHS=$(cat /home/"${USERNAME}"/migration_data/db-inventory/"${CONFIG_PATH_NAME}")
CREDS_PATH="/home/${USERNAME}/migration_data/db-inventory/$DB_CREDS_NAME"

for PATH in $CONFIG_PATHS; do
    DB_CREDS=$(/usr/bin/grep -E "DB_NAME|DB_USER|DB_PASS" $PATH | /usr/bin/awk '{print $2, $3}' | /usr/bin/sed "s/'//g" | /usr/bin/sed "s/,/:/g")
    echo "Finding credentials for $PATH"

    _DB_INVENTORY="/home/${USERNAME}/migration_data/db-inventory"
    if ! [[ -d "${_DB_INVENTORY}" ]]; then
      mkdir -p "${_DB_INVENTORY}"
      echo -e "\nFile Path: $PATH" >> "${CREDS_PATH}"
      echo "${DB_CREDS}" >> "${CREDS_PATH}"
    else
      echo -e "\nFile Path: $PATH" >> "${CREDS_PATH}"
      echo "${DB_CREDS}" >> "${CREDS_PATH}"
    fi
done
