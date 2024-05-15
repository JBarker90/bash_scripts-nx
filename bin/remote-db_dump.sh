#! /bin/bash

# Script Arguments
readonly ARGS="$*"
readonly ARGA=("$@")

# Configurable Variables
ssh_args=()

# Explicitly set PATH to be safe
PATH="/bin:/usr/bin:/usr/local/sbin:/sbin:/usr/sbin"

# Necessary Global Variables
ssh_user=""
ssh_host=""
remote_database=""
remote_my_conf=""
my_cnf_path=""

# Print usage
_usage() {

  cat <<- EOF
	$0 [options] <my.cnf_file_with_remote_creds>

	Dumps a single database from a remote server to the local server.

	Options:
	-d|--database <name>            The name of the database on the remote server
	-t|--table <name>               The name(s, comma separated) of the database table(s) on the remote server
	-f|--file <name|path>           Use the specified .my.cnf file with remote client creds
	-H|--ssh-host <hostname|alias>  Remote SSH server / SSH alias to connect to
	-u|--ssh-user <username>        Remote SSH username to use
	-h|--help                       Show this menu
	EOF

}

# Convert long command line options into short ones for getopts
_cmdline() {

  local x;

  for x in ${ARGA[*]}; do

    case "$x" in
      "--help"|"-h")
        args="${args}-h "
        ;;
      "--database"|"-d")
        args="${args}-d "
        ;;
      "--file"|"-f")
        args="${args}-f "
        ;;
      "--ssh-host"|"-H")
        args="${args}-H "
        ;;
      "--table"|"-t")
        args="${args}-t "
        ;;
      "--ssh-user"|"-u")
        args="${args}-u "
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

# Prerequisite checks
prereq () {

  local cmdline;

  mapfile -t cmdline < <(_cmdline | tr ' ' '\n');

  while getopts ":hd:f:H:t:u:" OPTION "${cmdline[@]}"; do

    case $OPTION in
      h)
        _usage
        exit 0
        ;;
      d)
        if [[ -n "${OPTARG}" ]]; then
          remote_database="${OPTARG}"
        else
          echo "No database name provided for -d."
          exit 1
        fi
        ;;
      f)
        if [[ -n "${OPTARG}" && -e "${OPTARG}" ]]; then
          remote_my_conf="$(readlink -f "${OPTARG}")"
        else
          echo "No .my.cnf file provided for -f."
          exit 1
        fi
        ;;
      H)
        if [[ -n "${OPTARG}" ]]; then
          ssh_host="${OPTARG}"
        else
          echo "No SSH host / alias provided for -H."
          exit 1
        fi
        ;;
      t)
        if [[ -n "${OPTARG}" ]]; then
          # shellcheck disable=SC2001
          readarray -t remote_tables < <(sed 's/,$//g' <<< "${OPTARG}" | tr ',' '\n')
        else
          echo "No table name(s) provided for -t."
          exit 1
        fi
        ;;
      u)
        if [[ -n "${OPTARG}" ]]; then
          ssh_user="${OPTARG}"
          ssh_args+=("-l" "${ssh_user}")
        else
          echo "No SSH user provided for -u."
          exit 1
        fi
        ;;
      "?")
        echo "-${OPTARG} is not a supported option." >&2
        ;;
      *);;
    esac
  done

  if [[ -z "${remote_database}" ]]; then
    cat <<- EOF
		--database / -d is a required argument! Without it, we can't dump a database!

		EOF

    exit 1
  fi

  if [[ -z "${ssh_host}" ]]; then
    cat <<- EOF
		--ssh-host / -H is a required argument! Without it, we can't access the remote server!
		This CAN be an SSH host from ~/.ssh/config
		
		EOF

    exit 1
  fi

  if [[ -z "${remote_my_conf}" && -f "$(readlink -f "remote_my_cnf")" ]]; then
    remote_my_conf="$(readlink -f "remote_my_cnf")"
    my_cnf_path="${remote_my_conf}"
    cat <<- EOF
		No input specified for remote my.cnf config, found and using:
		${my_cnf_path}

		EOF
  elif [[ -z "${remote_my_conf}" ]]; then
    for arg in "$@"; do
      if [[ -e "${arg}" && -f "$(readlink -f "${arg}")" ]]; then
        remote_my_conf="$(readlink -f "${arg}")"
      fi
    done
  fi

  if [[ -n "${remote_my_conf}" && -f "${remote_my_conf}" ]]; then
    my_cnf_path="${remote_my_conf}"
    cat <<- EOF
		Using specified remote my.cnf config:
		${my_cnf_path}

		EOF
  else
    echo "No remote my.cnf config found or provided, exiting..."
    exit 1
  fi

  if [[ -n "${ssh_user}" ]]; then
    if ! ssh -q -o 'BatchMode=yes' -o 'ConnectTimeout=3' "${ssh_args[@]}" "${ssh_host}" "exit"; then
      cat <<- EOF
			--ssh-user / -u was specified however, the SSH connection appears to be failing. Try testing with:
			ssh -o 'ConnectTimeout=3' "${ssh_args[@]}" "${ssh_host}" "exit"

			Command which was used for this test was:
			ssh -q -o 'BatchMode=yes' -o 'ConnectTimeout=3' "${ssh_args[@]}" "${ssh_host}" "exit"

			EOF

      exit 1
    fi
  else
    if ! ssh -q -o 'BatchMode=yes' -o 'ConnectTimeout=3' "${ssh_args[@]}" "${ssh_host}" "exit"; then
      cat <<- EOF
			No SSH user was specified, and the SSH connection appears to be failing. Try testing with:
      ssh -o 'ConnectTimeout=3' "${ssh_args[@]}" "${ssh_host}" "exit"

			Command which was used for thjis test was:
      ssh -q -o 'BatchMode=yes' -o 'ConnectTimeout=3' "${ssh_args[@]}" "${ssh_host}" "exit"

			EOF

      exit 1
    fi
  fi

}

# Main
main () {

  if [[ "$#" -lt 1 ]]; then
    _usage
    exit 0
  fi

  prereq "$@"

  if ssh "${ssh_args[@]}" "${ssh_host}" "df -t tmpfs /dev/shm &>/dev/null"; then
    temp_dir="/dev/shm/"
  else
    temp_dir="/tmp/"
  fi

  # shellcheck disable=SC2029
  output="$({ ssh "${ssh_args[@]}" "${ssh_host}" "mktemp -p ${temp_dir}"; echo "output_exit_code: $?"; } | awk '{gsub(/\r$/, ""); print}')"
  exit_code="$(grep -oP '^output_exit_code: \K.+$' <<< "${output}")"

  if [[ "${exit_code}" != 0 ]] && ! grep --color=auto -qv '^output_exit_code:' <<< "${output}"; then
    cat <<- EOF
		Command failed with exit code ${exit_code}. Output was:
		$(head -n -1 <<< "${output}")
		EOF
  	exit 1
  fi

  remote_temp_file="$(head -n1 <<< "${output}")"

  if [[ -z "${ssh_args[*]}" ]]; then
    rsync -avPz "${my_cnf_path}" "${ssh_host}:${remote_temp_file}"
  else
    rsync -avPz "${my_cnf_path}" -e "${ssh_args[@]}" "${ssh_host}:${remote_temp_file}"
  fi

  echo

  # shellcheck disable=SC2029
  if ! ssh "${ssh_args[@]}" "${ssh_host}" "mysql --defaults-extra-file=${remote_temp_file} -e \"exit\""; then
    echo "Provided .my.cnf file appears to be invalid. I am exiting instead of dumping database."
    ssh "${ssh_args[@]}" "${ssh_host}" "rm ${remote_temp_file}"
    exit 1
  else
    if [[ "${#remote_tables[@]}" -ge 1 ]]; then
      ssh "${ssh_args[@]}" "${ssh_host}" "mysqldump --defaults-extra-file=${remote_temp_file} --opt --skip-lock-tables --routines ${remote_database} ${remote_tables[*]}" | pv -W | pigz --fast > "${HOME}/${ssh_host}+$(awk -F '=' '/host/ {print $2}' "${my_cnf_path}" | awk '{print $1}')+${remote_database}+table+$(date --iso-8601=minute).sql.gz" &
    else
      ssh "${ssh_args[@]}" "${ssh_host}" "mysqldump --defaults-extra-file=${remote_temp_file} --opt --skip-lock-tables --routines ${remote_database}" | pv -W | pigz --fast > "${HOME}/${ssh_host}+$(awk -F '=' '/host/ {print $2}' "${my_cnf_path}" | awk '{print $1}')+${remote_database}+$(date --iso-8601=minute).sql.gz" &
    fi
    sleep 0.5
    ssh "${ssh_args[@]}" "${ssh_host}" "rm ${remote_temp_file}"
    wait
  fi

}

main "$@"
