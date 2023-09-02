#!/bin/bash

# Check for NON root privileges
if [ "$(id -u)" -eq 0 ]; then
  echo "This script must NOT be run as root. Please use a regular user."
  exit 1
fi

### STATIC VARIABLES ###
MANAGER_PWD=$(cd "$(dirname "$0")" && pwd && cd - > /dev/null || exit 1)
########################

source_pod_file() {
  # Load pod informations file
  # if pod.sh file is not present, exit on failure
  pod="$1"
  if ! [ -d "$pod" ]; then
    echo "Directory not found: $MANAGER_PWD/$pod"
    exit 1
  fi
  echo "Loading pod informations file..."
  if [ -f "$PWD/$pod/pod.sh" ]; then
    . "$PWD/$pod/pod.sh" || exit 1
  else
    echo "File not found: $PWD/$pod/pod.sh"
    exit 1
  fi

  ####### Check for required variables #######
  ## 1. start function                      ##
  ## 2. source_env function                 ##
  ## 3. requirements function               ##
  ## 4. NAME                                ##
  ## 5. VERSION                             ##
  ## 6. RESTART_POLICY                      ##
  ############################################
  if [ -z "$(type -t start)" ] || [ "$(type -t start)" != "function" ]; then
    echo "Function not found: start"
    exit 1
  fi
  if [ -z "$(type -t source_env)" ] || [ "$(type -t source_env)" != "function" ]; then
    echo "Function not found: source_env"
    exit 1
  fi
  if [ -z "$(type -t requirements)" ] || [ "$(type -t requirements)" != "function" ]; then
    echo "Function not found: requirements"
    exit 1
  fi
  if [ -z "$NAME" ]; then
    echo "Variable not found: NAME"
    exit 1
  fi
  if [ -z "$VERSION" ]; then
    echo "Variable not found: VERSION"
    exit 1
  fi
  # no | always | on-success | on-failure | on-abnormal | on-abort | on-watchdog
  if [ -z "$RESTART_POLICY" ] || [ "$RESTART_POLICY" != "no" ] && [ "$RESTART_POLICY" != "always" ] && [ "$RESTART_POLICY" != "on-success" ] && [ "$RESTART_POLICY" != "on-failure" ] && [ "$RESTART_POLICY" != "on-abnormal" ] && [ "$RESTART_POLICY" != "on-abort" ] && [ "$RESTART_POLICY" != "on-watchdog" ]; then
    echo "
    RESTART_POLICY is not properly set.
    Please set it to 'no' | 'always' | 'on-success' | 'on-failure' | 'on-abnormal' | 'on-abort' | 'on-watchdog'.
    RESTART_POLICY: \`$RESTART_POLICY\`
    "
    exit 1
  fi
}

create_systemd_service() {
  echo "Creating systemd service for $NAME..."
  mkdir -p "$HOME/.config/systemd/user"
  podman generate systemd \
    --new \
    --name "$NAME" \
    --restart-policy "$RESTART_POLICY" \
    > "$HOME/.config/systemd/user/container-$NAME.service"
  systemctl --user enable "container-$NAME.service"
  systemctl --user start "container-$NAME.service"
  systemctl --user daemon-reload
}

create() {
  pod="$1"
  source_pod_file "$pod"
  source_env || {
    echo "Error loading environment variables."
    exit 1
  }
  requirements || {
    echo "Error loading requirements."
    exit 1
  }
  start || {
    echo "Error starting pod."
    exit 1
  }
  echo "Pod $NAME created."
  create_systemd_service || {
    echo "Error creating systemd service."
    exit 1
  }
}

delete_systemd_service() {
  echo "Removing systemd service for $NAME..."
  systemctl --user disable "container-$NAME.service"
  rm "$HOME/.config/systemd/user/container-$NAME.service"
  systemctl --user daemon-reload
}

destroy() {
  pod="$1"
  source_pod_file "$pod"
  source_env
  echo "Stopping pod $NAME..."
  podman stop "$NAME"
  echo "Removing pod $NAME..."
  podman rm "$NAME"
}

show_help() {
  echo "
  Usage: ${0##*/} [-h] [-c|-d POD]

  Manage pods.

  -h, -?, --help  display this help and exit
  -c, --create    create a pod
  -d, --destroy   destroy a pod
  "
}

# argument parsing
while :; do
  case "$1" in
    -h|--help|-\?) show_help; exit 0 ;;
    -c|--create) create "$2"; shift ;;
    -d|--destroy) destroy "$2"; shift ;;
    --) shift; break ;;
    -?*) printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2 ;;
    *) break ;;
  esac
done
