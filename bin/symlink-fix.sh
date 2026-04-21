#! /bin/bash

# Script Arguments
readonly ARGA=("$@")

# Script version
_VERSION="1.0.0"

# Explicitly set path to be safe
PATH="/bin:/usr/bin:/usr/local/sbin:/sbin:/usr/sbin"

# Necessary Global Variables
OLD_DOMAIN=""
OLD_USER=""
FILE_PATH=""

# Print usage
_usage() {

  cat <<- EOF
	$(basename "$0") <options>

	Options:
	-u|--user     The Old UNIX User. This is the old user seen in broken symlink path
	-d|--domain   The Old domain. This is the old domain seen in broken symlink path
	-f|--file     This is the file path you want the script to run through
	-h|--help     Show this menu
	-v|--version  Show script version information
	EOF

}

# Convert long command line options into short ones for getopts
_cmdline() {

  local x

  for x in "${ARGA[@]}"; do

    case "${x}" in
      "--user"|"-u")
        args="${args}-u "
        ;;
      "--domain"|"-d")
        args="${args}-d "
        ;;
      "--file"|"-f")
        args="${args}-f "
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

_broken_symlinks(){
	local _OLD_SYMLINK_BAK

	_OLD_SYMLINK_BAK="/home/${UNIX_USER}/old-symlinks.txt"
	if [[ -d "${FILE_PATH}" ]]; then
		mapfile -t broken_symlinks < <(find "${FILE_PATH}" -maxdepth 5 -xtype l | sort )

		if ! [[ -f "${_OLD_SYMLINK_BAK}" ]]; then
			echo "Backing up old symlinks to $_OLD_SYMLINK_BAK"
			touch "${_OLD_SYMLINK_BAK}"
			printf "%s\n" "${broken_symlinks[@]}" > "${_OLD_SYMLINK_BAK}"
		else
			echo "Backing up old symlinks to $_OLD_SYMLINK_BAK"
			printf "%s\n" "${broken_symlinks[@]}" > "${_OLD_SYMLINK_BAK}"
		fi
	fi
}

_location_fix(){
	_broken_symlinks

	echo "Updating broken symlinks now..."
	for _LINK in "${broken_symlinks[@]}"; do
		old_location=$(readlink "$_LINK")
		new_location=$(echo "$old_location" | sed "s/$OLD_USER/$UNIX_USER/; s/$OLD_DOMAIN/$DOMAIN/")

		ln -snf "$new_location" "$_LINK"
	done
	echo "Update is now complete!"
}

# Prerequisite checks
_prereq() {

  local -a cmdline

  mapfile -t cmdline < <(_cmdline | tr ' ' '\n')

  while getopts ":hu:d:f:v" OPTION "${cmdline[@]}"; do

    case "${OPTION}" in
      h)
        _usage
        exit 0
        ;;
      u)
        if [[ -n "${OPTARG}" ]]; then
          OLD_USER="${OPTARG}"
        else
          echo "No Old UNIX user is provided."
          exit 1
        fi
        ;;
      d)
        if [[ -n "${OPTARG}" ]]; then
          OLD_DOMAIN="${OPTARG}"
        else
          echo "No Old domain is provided."
          exit 1
        fi
        ;;
      f)
        if [[ -n "${OPTARG}" ]]; then
          FILE_PATH="${OPTARG}"
        else
          echo "No file path is provided."
          exit 1
        fi
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

	if [[ -z "${FILE_PATH}" ]]; then
		echo "No File Path provided. Please use one of these options [-f|--file]"
		exit 1
	fi
}

# Main
main() {

  _prereq "${ARGA[@]}"

  UNIX_USER=$(readlink -f "${FILE_PATH} "| cut -d '/' -f4)
  DOMAIN=$(readlink -f "${FILE_PATH} "| cut -d '/' -f5)
  _location_fix
}

main
