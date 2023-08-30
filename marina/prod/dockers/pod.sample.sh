#!/bin/sh

### STATIC VARIABLES ###
PWD=$(cd "$(dirname "$0")" && pwd && cd - > /dev/null || exit 1)
NAME=
VERSION=
########################

source_env() {
  # Load environment variables
  # if .env file is not present, exit on failure
  echo "Loading environment variables from .env file..."
  if [ -f "$PWD/.env" ]; then
    . "$PWD/.env"
    return $?
  else
    echo "File not found: $PWD/.env"
    exit 1
  fi

  ####### Check for required variables #######
  ## 1. ...                                 ##
  ############################################
}

start() {
  podman run \
    --name "$NAME" \
    # ...
    "container:$VERSION"
}
