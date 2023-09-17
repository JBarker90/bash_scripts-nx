#!/bin/bash

DOMAIN=$1
if [ -L "/Users/jbarker/$DOMAIN" ]; then
  tmp=$(mktemp)
  link_target=$(readlink -f /Users/jbarker/"$DOMAIN")
  echo "Symbolic link exists and points to $link_target"
  echo "Temporary variable created: $tmp"
  # Do something with the temporary variable and link_target here
else
  echo "Symbolic link does not exist"
fi

rm "$tmp"