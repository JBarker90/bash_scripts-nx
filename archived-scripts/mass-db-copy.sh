#!/bin/bash

# Script Arguments
readonly ARGA=("$@")

# Necessary Variables
UNIX_USER=""
CONFIG_LIST_NAME=""
DB_DIRECTORY=""
DB_CREDS_NAME="db-credentials.txt"

# Print usage
_usage() {

  cat <<- EOF
	$0 [options]

	Loops over multiple databases to dump or import.

	Options:
	-l|--list-file <name>           This specifies the file containing the list of config file paths
	-D|--directory <name|path>      This directory specifies the name of the backups to target
	-U|--unix-user <user>           Unix user. This is the will be the Siteworx user.
	-u|--user <user>                Database user.
	-p|--password <pass>            Password for database user.
	-e|--export                     This loops through the databases and dumps them
	-i|--import                     This loops through the databases and imports them
	-h|--help                       Show this menu
	EOF

}

# Convert long command line options into short ones for getopts
_cmdline() {

  local x;

  for x in "${ARGA[@]}"; do

    case "$x" in
      "--help"|"-h")
        args="${args}-h "
        ;;
      "--list-file"|"-l")
        args="${args}-l "
        ;;
      "--directory"|"-D")
        args="${args}-D "
        ;;
      "--unix-user"|"-U")
        args="${args}-U "
        ;;
      "--user"|"-u")
        args="${args}-u "
        ;;
      "--password"|"-p")
        args="${args}-p "
        ;;
      "--export"|"-e")
        args="${args}-e "
        ;;
      "--import"|"-i")
        args="${args}-i "
        ;;
      "--"*)
        echo "$x is not a supported option." >&2
        ;;
      *)
        args="${args}${x} "
        ;;
    esac
  done

  echo "$args";

}

_inventory(){
  local _DB_INVENTORY CONFIG_PATHS DB_CREDS CREDS_PATH

  _DB_INVENTORY="/home/${UNIX_USER}/migration_data/db-inventory"
  CREDS_PATH="/home/${UNIX_USER}/migration_data/db-inventory/$DB_CREDS_NAME"
  if [[ -e "${CONFIG_LIST_NAME}" ]] && ! [[ -s "${CREDS_PATH}" ]]; then
      CONFIG_PATHS=$(/usr/bin/cat /home/"${UNIX_USER}"/migration_data/db-inventory/"${CONFIG_LIST_NAME}")
      for PATH in $CONFIG_PATHS; do
        DB_CREDS=$(/usr/bin/grep -E "DB_NAME|DB_USER|DB_PASS" "${PATH}" | /usr/bin/awk '{print $2, $3}' | /usr/bin/sed "s/'//g; s/,/:/g")
        echo "Finding credentials for $PATH"

        if ! [[ -d "${_DB_INVENTORY}" ]]; then
          /usr/bin/mkdir -p "${_DB_INVENTORY}"
          echo -e "\nFile Path: $PATH" >> "${CREDS_PATH}"
          echo "${DB_CREDS}" >> "${CREDS_PATH}"
        else
          echo -e "\nFile Path: $PATH" >> "${CREDS_PATH}"
          echo "${DB_CREDS}" >> "${CREDS_PATH}"
        fi

      done
  fi
}

_export(){
  local CONFIG_PATHS _DB_ARCHIVE CREDS_PATH

  _inventory

  CREDS_PATH="/home/${UNIX_USER}/migration_data/db-inventory/$DB_CREDS_NAME"
  if [[ -e "${CREDS_PATH}" ]]; then
      CONFIG_PATHS=$(/usr/bin/cat /home/"${UNIX_USER}"/migration_data/db-inventory/"${CONFIG_LIST_NAME}")
      for PATH in $CONFIG_PATHS; do
        db_name=$(/usr/bin/grep -A3 "${PATH}" "${CREDS_PATH}" | /usr/bin/grep 'DB_NAME' | /usr/bin/awk '{print $2}')
        db_user=$(/usr/bin/grep -A3 "${PATH}" "${CREDS_PATH}" | /usr/bin/grep 'DB_USER' | /usr/bin/awk '{print $2}')
        db_pass=$(/usr/bin/grep -A3 "${PATH}" "${CREDS_PATH}" | /usr/bin/grep 'DB_PASSWORD' | /usr/bin/awk '{print $2}')

        echo -e "\nDumping $db_name to $_DB_ARCHIVE/$db_name-$(/usr/bin/date '+%F').sql.gz"

        _DB_ARCHIVE="/home/${UNIX_USER}/migration_data/database_archives/db-backups-$(/usr/bin/date '+%F')"
        if ! [[ -d "${_DB_ARCHIVE}" ]]; then
          echo -e "\nCreating $_DB_ARCHIVE..."
          /usr/bin/mkdir -p "${_DB_ARCHIVE}"
          /usr/bin/mysqldump --opt --quick --routines --skip-triggers --skip-lock-tables --no-tablespaces -u "$db_user" -p"$db_pass" "$db_name" | /usr/bin/gzip -c > "$_DB_ARCHIVE"/"$db_name"-"$(/usr/bin/date '+%F')".sql.gz &
        else
          /usr/bin/mysqldump --opt --quick --routines --skip-triggers --skip-lock-tables --no-tablespaces -u "$db_user" -p"$db_pass" "$db_name" | /usr/bin/gzip -c > "$_DB_ARCHIVE"/"$db_name"-"$(/usr/bin/date '+%F')".sql.gz &
        fi
      done
  else
      echo "Please create an inventory list of config files."
      echo "$0 -l $CONFIG_LIST_NAME -c"
      exit 1
  fi
}

_import(){
  local DB_FILES _SOURCE_DB_USER db_name

  DB_FILES="/home/${UNIX_USER}/migration_data/database_archives/$DB_DIRECTORY"
  if [[ -d $DB_FILES ]]; then
      for filename in "$DB_FILES"/*; do
        _SOURCE_DB_USER=$(echo "$filename" | /bin/cut -d '/' -f7 | /usr/bin/awk -F '-' '{print "DB_NAME: "$1}' | /bin/xargs -I {} grep -B1 "{}" $DB_CREDS_NAME | /bin/cut -d '/' -f3 | /bin/head -n1)
        db_name=$(echo "$filename" | /bin/cut -d '/' -f7 | /usr/bin/awk -v s="$_SOURCE_DB_USER" -F '[_.-]' '{if ($1 == s) print $2; else print $1}' | /usr/bin/sed s/^/"$UNIX_USER"_/g)

        echo -e "\nImporting $db_name..."

        importdb -U "${UNIX_USER}" -d "$db_name" -u "$_DEST_DB_USER" -p "$_DEST_DB_PASS" -f "$filename" -y
        sleep 1
      done
  else
      echo "We cannot find backups in $(readlink -f "$DB_FILES"). Please check the directory."
      exit 1
  fi
}

main(){
  if [[ "$#" -lt 1 ]]; then
    _usage
    exit 0
  fi

  local cmdline;

  mapfile -t cmdline < <(_cmdline | tr ' ' '\n');

  while getopts ":hl:D:U:u:p:ei" OPTION "${cmdline[@]}"; do

    case $OPTION in
      h)
        _usage
        exit 0
        ;;
      l)
        if [[ -n "${OPTARG}" ]]; then
          CONFIG_LIST_NAME="${OPTARG}"
        else
          echo "No config-paths file provided."
          exit 1
        fi
        ;;
      D)
        if [[ -n "${OPTARG}" ]]; then
          DB_DIRECTORY="${OPTARG}"
        else
          echo "No database backup directory is provided."
          exit 1
        fi
        ;;
      U)
        if [[ -n "${OPTARG}" ]]; then
          UNIX_USER="${OPTARG}"
        else
          echo "No Siteworx user is provided."
          exit 1
        fi
        ;;
      u)
        if [[ -n "${OPTARG}" ]]; then
          _DEST_DB_USER="${OPTARG}"
        else
          echo "No database user is provided."
          exit 1
        fi
        ;;
      p)
        if [[ -n "${OPTARG}" ]]; then
          _DEST_DB_PASS="${OPTARG}"
        else
          echo "No database password is provided."
          exit 1
        fi
        ;;
      e)
        _export
        exit 0
        ;;
      i)
        _import
        exit 0
        ;;
      "?")
        echo "-${OPTARG} is not a supported option." >&2
        ;;
      *);;
    esac
  done
}

main "$@"
