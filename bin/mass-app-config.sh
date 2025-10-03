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
IS_REDIS_SOCK=0
DB_CREDS_NAME="db-credentials.txt"

# Print usage
_usage() {

  cat <<- EOF
		$(basename "$0") <options>

		Options:
		-l|--list-file                  This specifies the file containing the list of config file paths
		-U|--unix-user <user>           Unix user. This is the will be the Siteworx user.
		-u|--db-user <user>             Database user.
		-p|--db-password <pass>         Password for database user.
		-c|--db-config                  Updates DB creds in app config file.
		-r|--redis-config               Configures Redis plugin and updates app config file.
		-h|--help                       Show this menu.
		-v|--version                    Show script version information.
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
      "--db-user"|"-u")
        args="${args}-u "
        ;;
      "--db-password"|"-p")
        args="${args}-p "
        ;;
      "--db-config"|"-c")
        args="${args}-c "
        ;;
      "--redis-config"|"-r")
        args="${args}-r "
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
      echo "The Database Name has updated to $_DEST_DB_NAME"
    fi

    if [[ "$_DEST_DB_USER" == "$_SOURCE_DB_USER" ]]; then
      echo "The Database User is the same. Skipping this configuration."
    else
      sed -i "s/\(define( 'DB_USER', '\)[^']\+'/\1$_DEST_DB_USER'/" "${_PATH}"
      echo "The Database User has updated to $_DEST_DB_USER"
    fi

    if [[ "$_DEST_DB_PASS" == "$_SOURCE_DB_PASS" ]]; then
      echo "The Database Password is the same. Skipping this configuration."
    else
      sed -i "s/\(define( 'DB_PASSWORD', '\)[^']\+'/\1$_DEST_DB_PASS'/" "${_PATH}"
      echo "The Database Password has updated to $_DEST_DB_PASS"
    fi

    if [[ "$_DEST_DB_HOST" == "$_SOURCE_DB_HOST" ]]; then
      echo "The Database Host is the same. Skipping this configuration."
    else
      sed -i "s/\(define( 'DB_HOST', '\)[^']\+'/\1$_DEST_DB_HOST'/" "${_PATH}"
      echo "The Database Host has updated to $_DEST_DB_HOST"
    fi
  done < <(cat "${CONFIG_LIST_NAME}")

  fi
}

_redis_config(){
  local _DOC_ROOT _OCP_CODE_BLOCK _OCP_HA_CODE_BLOCK _REDIS_DB _REDIS_PORT _REDIS_HOST _OCP_TOKEN _REDIS_INSTANCE _REDIS_HA_PREFIX

  _REDIS_DB=0

  if [[ -e "${CONFIG_LIST_NAME}" ]]; then
  while read -r _PATH; do 
  _DOC_ROOT=$(echo "$_PATH" | cut -d '/' -f-5)
  _OCP_TOKEN=""
  _OCP_HA_CODE_BLOCK="
  # Redis Object Cache Pro - ESG Projects
  define( 'WP_REDIS_CONFIG', [
    'token' => '$_OCP_TOKEN',
    'servers' => [
        'tcp://$_REDIS_HA_PREFIX.$_REDIS_INSTANCE:$_REDIS_PORT?role=master',
        'tcp://127.0.0.1:$_REDIS_PORT?role=replica',
    ],
    'replication_strategy' => 'distribute_replicas',
    'database' => '$_REDIS_DB',
    'maxttl' => 3600 * 12, // 12 hours
    'timeout' => 2.5,
    'read_timeout' => 2.5,
    'retry_interval' => 10,
    'retries' => 2,
    'backoff' => 'smart',
    'compression' => 'zstd',
    'serializer' => 'igbinary',
    'async_flush' => true,
    'split_alloptions' => true,
    'prefetch' => true,
    'debug' => false,
    'save_commands' => false,
    'non_persistent_groups' => [
        'ywpar_points',
        'wp-all-import-pro',
      ],
  ] );
  define( 'WP_REDIS_DISABLED', false );
  "
  _OCP_CODE_BLOCK="
  # Redis Object Cache Pro - ESG Projects
  define( 'WP_REDIS_CONFIG', [
    'token' => '$_OCP_TOKEN',
    'host' => '$_REDIS_HOST',
    'port' => '$_REDIS_PORT',
    'database' => '$_REDIS_DB',
    'maxttl' => 86400 * 7,
    'timeout' => 1.0,
    'read_timeout' => 1.0,
    'retry_interval' => 10,
    'retries' => 3,
    'backoff' => 'smart',
    'compression' => 'zstd',
    'serializer' => 'igbinary',
    'async_flush' => true,
    'split_alloptions' => true,
    'prefetch' => true,
    'debug' => false,
    'save_commands' => false,
    'non_persistent_groups' => [
        'ywpar_points',
    ],
  ] );
  define( 'WP_REDIS_DISABLED', false );
  "

    echo -e "\nBeginning Redis configuration for $_DOC_ROOT"
    cd "$_DOC_ROOT" || exit

    if [[ "$UID" != 0 ]]; then
      echo "You need to be root to run this script"
      exit 1
    else
      if ! [[ -f "${_PATH}_$(date '+%F')" ]]; then
        echo "Backing up config file $_PATH"
        cp -ap "${_PATH}" "${_PATH}_$(date '+%F')"
      else
        echo "Config file already backed up. Skipping"
      fi
      echo "Installing Object Cache Pro plugin for $_PATH"
      sudo -iu "$UNIX_USER" bash -c "/usr/local/bin/wp --path=\"$(pwd -P)\" plugin install https://a365f64bd6.nxcli.net/wp-content/plugins/object-cache-pro.zip --force"

      case "${IS_REDIS_SOCK}" in 
        0)
          if [[ "${IS_CLUSTER}" = 1 ]]; then
            _REDIS_INSTANCE=$(nkredis info "$UNIX_USER" | grep ' ID' | awk '{print $4}' | cut -d '-' -f-2)
            _REDIS_HA_PREFIX=$(hostname | cut -d '-' -f1 | sed 's/$/-ha/g')
            _REDIS_PORT=$(nkredis info "$UNIX_USER" | grep 'TCP Sockets' | awk '{print $4}' | cut -d ':' -f2)
            echo -e "$_OCP_HA_CODE_BLOCK" >> "${_PATH}"
          else
            _REDIS_HOST=$(nkredis info "$UNIX_USER" | grep 'TCP ' | awk '{print $4}' | cut -d ':' -f1)
            _REDIS_PORT=$(nkredis info "$UNIX_USER" | grep 'TCP ' | awk '{print $4}' | cut -d ':' -f2)
            echo -e "$_OCP_CODE_BLOCK" >> "${_PATH}"
          fi
          ;;
        1)
          _REDIS_HOST=$(nkredis info "$UNIX_USER" | grep 'Unix ' | awk '{print $4}')
          _REDIS_PORT=0
          echo -e "$_OCP_CODE_BLOCK" >> "${_PATH}"
          ;;
      esac
      sudo -iu "$UNIX_USER" bash -c "/usr/local/bin/wp --path=\"$(pwd -P)\" plugin activate object-cache-pro"
      sudo -iu "$UNIX_USER" bash -c "/usr/local/bin/wp --path=\"$(pwd -P)\" enable --force"
      sudo -iu "$UNIX_USER" bash -c "/usr/local/bin/wp --path=\"$(pwd -P)\" cache flush"
    fi
    _REDIS_DB=$((_REDIS_DB + 1))

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
    sip*|csip*|*-dev*) 
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

  if grep -qF 'unixsocket ' /etc/redis-multi/*.conf; then
    IS_REDIS_SOCK=1
  fi

  mapfile -t cmdline < <(_cmdline | tr ' ' '\n')

  while getopts ":hvl:U:u:p:cr" OPTION "${cmdline[@]}"; do

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
      r)
        _redis_config
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

  if [[ "$#" -lt 1 ]]; then
    _usage
    exit 0
  fi

  _prereq "${ARGA[@]}"

}

main "$@"
