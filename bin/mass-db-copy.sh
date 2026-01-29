#!/bin/bash

# Script Arguments
readonly ARGA=("$@")

# Necessary Variables
UNIX_USER=""
DB_DIRECTORY=""
DB_NAME_LIST="'$UNIX_USER'_db-list.txt"

# Print usage
_usage() {

  cat <<- EOF
	$0 [options]

	Loops over multiple databases to dump or import.

	Options:
	-D|--directory <name|path>      This directory specifies the name of the backups to target
	-U|--unix-user <user>           Unix user. This is the will be the Control Panel user.
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
  local _DB_INVENTORY _SRC_DB _SRC_DB_LIST

  _DB_INVENTORY="/home/${UNIX_USER}/migration_data/db-inventory"
  _SRC_DB_LIST="/home/${UNIX_USER}/migration_data/db-inventory/$DB_NAME_LIST"
  if ! [[ -s "${_SRC_DB_LIST}" ]]; then
      _SRC_DB=$(mysql -e "show databases;" |grep -Pv '^(Database|information_schema|performance_schema)$' | grep "^$UNIX_USER")
      for DB in $_SRC_DB; do

        if ! [[ -d "${_DB_INVENTORY}" ]]; then
          /usr/bin/mkdir -p "${_DB_INVENTORY}"
          echo "${DB}" >> "${_SRC_DB_LIST}"
        else
          echo "${DB}" >> "${_SRC_DB_LIST}"
        fi

      done
  fi
}

_export(){
  local _DB_ARCHIVE _SRC_DB_LIST

  _inventory

  _SRC_DB_LIST="/home/${UNIX_USER}/migration_data/db-inventory/$DB_NAME_LIST"
  if [[ -e "${_SRC_DB_LIST}" ]]; then
      _SRC_DBS=$(/usr/bin/cat "$_SRC_DB_LIST")
      for DB in $_SRC_DBS; do
        _DB_ARCHIVE="/home/${UNIX_USER}/migration_data/database_archives/db-backups-$(/usr/bin/date '+%F')"
        if ! [[ -d "${_DB_ARCHIVE}" ]]; then
          echo -e "\nCreating $_DB_ARCHIVE..."
          /usr/bin/mkdir -p "${_DB_ARCHIVE}"
					echo -e "\nDumping $DB to $_DB_ARCHIVE/$DB-$(/usr/bin/date '+%F').sql.gz"
          /usr/bin/mysqldump --opt --quick --routines --skip-triggers --skip-lock-tables --no-tablespaces -u "$_DEST_DB_USER" -p"$_DEST_DB_PASS" "$DB" | /usr/bin/gzip -c > "$_DB_ARCHIVE"/"$DB"-"$(/usr/bin/date '+%F')".sql.gz &
        else
					echo -e "\nDumping $DB to $_DB_ARCHIVE/$DB-$(/usr/bin/date '+%F').sql.gz"
          /usr/bin/mysqldump --opt --quick --routines --skip-triggers --skip-lock-tables --no-tablespaces -u "$_DEST_DB_USER" -p"$_DEST_DB_PASS" "$DB" | /usr/bin/gzip -c > "$_DB_ARCHIVE"/"$DB"-"$(/usr/bin/date '+%F')".sql.gz &
        fi
      done
  else
      echo "Could not find the following path $_SRC_DB_LIST"
      exit 1
  fi
}

_import(){
  local DB_FILES _SOURCE_DB_USER db_name

  DB_FILES="/home/${UNIX_USER}/migration_data/database_archives/$DB_DIRECTORY"
  if [[ -d $DB_FILES ]]; then
      for filename in "$DB_FILES"/*; do
        _SOURCE_DB_USER=$(echo "$filename" | /bin/cut -d '/' -f7 | cut -d '_' -f1)
        db_name=$(echo "$filename" | /bin/cut -d '/' -f7 | sed s/^"$_SOURCE_DB_USER"/"$UNIX_USER"/g | cut -d '-' -f1 )

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

  while getopts ":hD:U:u:p:ei" OPTION "${cmdline[@]}"; do

    case $OPTION in
      h)
        _usage
        exit 0
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
