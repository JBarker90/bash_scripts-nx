#!/bin/bash

# Script Arguments
readonly ARGA=("$@")

# Script version
_VERSION="1.0.0"

# Explicitly set path to be safe
PATH="/bin:/usr/bin:/usr/local/sbin:/sbin:/usr/sbin"

# Necessary Global Variables
UNIX_USER=""
CONFIG_LIST_NAME=""
IS_CLUSTER=""
DB_CREDS_NAME="db-credentials.txt"

# Print usage
_usage() {

  cat <<- EOF
		$(basename "$0") <options>

		Options:
		-l|--list-file                  This specifies the file containing the list of config file paths
		-U|--unix-user <user>           Unix user. This is the will be the Siteworx user.
		-u|--user <user>                Database user.
		-p|--password <pass>            Password for database user.
		-c|--config-update              Password for database user.
		-h|--help                       Show this menu
		-v|--version                    Show script version information
	EOF

}

# Convert long command line options into short ones for getopts
_cmdline() {

  local x

  for x in "${ARGA[@]}"; do

    case "${x}" in
      "--list-file"|"-l")
        args="${args}-l "
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
      "--config-update"|"-c")
        args="${args}-c "
        ;;
      "--help"|"-h")
        args="${args}-h "
        ;;
      "--version"|"-v")
        args="${args}-v "
        ;;
      "--"*)
        echo "${x} is not a supported option." >&2
        ;;
      *)
        args="${args}${x} "
        ;;
    esac
  done

  echo "${args}"

}

_db_config(){
  local CREDS_PATH _SOURCE_UNIX_USER _DEST_DB_NAME _SOURCE_DB_NAME _SOURCE_DB_USER _SOURCE_DB_PASS _SOURCE_DB_HOST

  if [[ -e "${CONFIG_LIST_NAME}" ]]; then
  while read -r _PATH; do
    CREDS_PATH="/home/${UNIX_USER}/migration_data/db-inventory/$DB_CREDS_NAME"
    _SOURCE_UNIX_USER=$(grep 'File Path: ' "$CREDS_PATH" | head -n1 | awk '{print $3}' | cut -d '/' -f3)
    _DEST_DB_NAME=$(grep 'DB_NAME' "${_PATH}" | awk '{print $3}' | sed "s/'//g" | awk -v s="$_SOURCE_UNIX_USER" -F '[_.-]' '{if ($1 == s) print $2; else print $1}' | sed s/^/"$UNIX_USER"_/g)
    _SOURCE_DB_NAME=$(grep 'DB_NAME' "${_PATH}" | awk '{print $3}' | sed "s/'//g")
    _SOURCE_DB_USER=$(grep 'DB_USER' "${_PATH}" | awk '{print $3}' | sed "s/'//g")
    _SOURCE_DB_PASS=$(grep 'DB_PASS' "${_PATH}" | awk '{print $3}' | sed "s/'//g")
    _SOURCE_DB_HOST=$(grep 'DB_HOST' "${_PATH}" | awk '{print $3}' | sed "s/'//g")

    echo -e "\nBacking up config $_PATH"

    cp -ap "${_PATH}" "${_PATH}_$(date '+%F')"

    echo "Updating Database configuration"
    if [[ "$_DEST_DB_NAME" == "$_SOURCE_DB_NAME" ]]; then
      echo "The Database Name is the same. Skipping this configuration."
    else
      sed -i "s/\(define( 'DB_NAME', '\)[^']\+'/\1$_DEST_DB_NAME'/" "${_PATH}"
    fi

    if [[ "$_DEST_DB_USER" == "$_SOURCE_DB_USER" ]]; then
      echo "The Database User is the same. Skipping this configuration."
    else
      sed -i "s/\(define( 'DB_USER', '\)[^']\+'/\1$_DEST_DB_USER'/" "${_PATH}"
    fi

    if [[ "$_DEST_DB_PASS" == "$_SOURCE_DB_PASS" ]]; then
      echo "The Database Password is the same. Skipping this configuration."
    else
      sed -i "s/\(define( 'DB_PASSWORD', '\)[^']\+'/\1$_DEST_DB_PASS'/" "${_PATH}"
    fi

    if [[ "$_DEST_DB_HOST" == "$_SOURCE_DB_HOST" ]]; then
      echo "The Database Host is the same. Skipping this configuration."
    else
      sed -i "s/\(define( 'DB_HOST', '\)[^']\+'/\1$_DEST_DB_HOST'/" "${_PATH}"
    fi
  done < <(cat "${CONFIG_LIST_NAME}")

  fi
}

cluster_set(){
  local _DB_NODES_COUNT _GALERA_DB_HOST _SINGLE_DB_HOST

  _DB_NODES_COUNT=$(grep -E "db" /etc/hosts | awk '{print $2}' | wc -l)
  _GALERA_DB_HOST=$(grep -E 'db-lb' /etc/hosts | awk '{print $3}')
  _SINGLE_DB_HOST=$(grep -E 'db' /etc/hosts | awk '{print $2}')

  case "${HOSTNAME}" in
    *-fs*)
      if [[ $_DB_NODES_COUNT -gt 2 ]]; then
        _DEST_DB_HOST=${_GALERA_DB_HOST}
      else
        _DEST_DB_HOST=${_SINGLE_DB_HOST}
      fi
      ;;
    *-lb*)
      if [[ $_DB_NODES_COUNT -gt 2 ]]; then
        _DEST_DB_HOST=${_GALERA_DB_HOST}
      else
        _DEST_DB_HOST=${_SINGLE_DB_HOST}
      fi
      ;;
    *)
      echo "I don't know what type of server this is."
      exit 1
      ;;
  esac

}

# Prerequisite checks
_prereq() {

  local -a cmdline

  case "$(hostname)" in
    sip*|csip*) 
      IS_CLUSTER=0
      _DEST_DB_HOST="localhost" 
      ;;
    ece*|mce*|wce*|gpc*|cgpc*)
      IS_CLUSTER=1
      cluster_set
      ;;
    cloud*)
      if [[ "$UID" != 0 ]]; then
        echo "You need to be root to run this script"
        exit 1
      fi
      IS_CLUSTER=0
      _DEST_DB_HOST="localhost" 
      ;;
    *)
      echo "Unknown type. Stopping script"
      exit 1
      ;;
  esac


  mapfile -t cmdline < <(_cmdline | tr ' ' '\n')

  while getopts ":hvl:U:u:p:c" OPTION "${cmdline[@]}"; do

    case "${OPTION}" in
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
      c)
        _db_config
        exit 0
        ;;
      v)
        echo "$(basename "$0") version: ${_VERSION}"
        exit 0
        ;;
      "?")
        echo "-${OPTARG} is not a supported option." >&2
        ;;
      *);;
    esac
  done

}

# Main
main() {

  _prereq "${ARGA[@]}"

}

main

