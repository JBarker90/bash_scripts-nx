#!/bin/bash

if [ -L "/path/to/symlink" ]; then
  tmp=$(mktemp)
  link_target=$(readlink -f /path/to/symlink)
  echo "Symbolic link exists and points to $link_target"
  echo "Temporary variable created: $tmp"
  # Do something with the temporary variable and link_target here
else
  echo "Symbolic link does not exist"
fi