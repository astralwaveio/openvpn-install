#!/usr/bin/env bash

# openvpn-ctl
# Universal OpenVPN client management tool for Angristan's openvpn-install.sh
# Author: Astral Wave
# License: MIT

set -euo pipefail

# Use openvpn-install.sh in the same directory as this script, unless overridden by env
OPENVPN_SCRIPT="${OPENVPN_SCRIPT:-$(dirname "$0")/openvpn-install.sh}"

# Optional: custom .ovpn output/search directory
# export OVPN_OUTPUT_DIR="/data/openvpn-clients"

# Auto-install expect if not present (for future extensions, not used for user mgmt)
function ensure_expect_installed() {
  if ! command -v expect >/dev/null 2>&1; then
    echo "expect not found, installing automatically..."
    if command -v apt-get >/dev/null 2>&1; then
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -y && apt-get install -y expect
    elif command -v yum >/dev/null 2>&1; then
      yum install -y expect
    elif command -v dnf >/dev/null 2>&1; then
      dnf install -y expect
    else
      echo "No suitable package manager found for installing expect."
      exit 2
    fi
  fi
}

ensure_expect_installed

print_usage() {
  cat <<EOF
openvpn-ctl - OpenVPN user management for Angristan's openvpn-install.sh

Usage:
  $0 add <username> [--pass <password>]           # Add user (with optional private key password)
  $0 revoke <username>                            # Revoke user
  $0 list                                         # List all users
  $0 regen <username> [--pass <password>]         # Revoke and re-add user
  $0 show <username>                              # Print .ovpn config to stdout
  $0 export <username> <output_path>              # Export .ovpn config to a file

Options:
  --pass <password>    Set private key password for the user (only on add/regen)

Examples:
  $0 add alice
  $0 add bob --pass mypassword
  $0 revoke alice
  $0 regen bob --pass newpassword
  $0 list
  $0 show alice
  $0 export alice /tmp/alice.ovpn

Environment Variables:
  OPENVPN_SCRIPT      Path to openvpn-install.sh (default: current dir)
  OVPN_OUTPUT_DIR     Directory to store and look for .ovpn files (default: script dir, /root, or cwd)

Notes:
- This script manages users only. Do not use for installation or uninstallation.
- Requires Angristan's openvpn-install.sh (2022+ version) with --add, --remove, --list support.
- All actions are non-interactive and safe for automation/CI.
- openvpn-install.sh must be in the same directory as openvpn-ctl, or specify OPENVPN_SCRIPT env.
EOF
  exit 1
}

# Check openvpn-install.sh existence and executability
if [[ ! -x "$OPENVPN_SCRIPT" ]]; then
  echo "Error: $OPENVPN_SCRIPT not found or not executable."
  exit 2
fi

CMD="${1:-}"
USER="${2:-}"
shift $(( $# > 0 ? 1 : 0 ))
shift $(( $# > 0 ? 1 : 0 ))

# Parse optional arguments (--pass)
USER_PASS=""
OUTPUT_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pass)
      shift
      USER_PASS="$1"
      ;;
    *)
      if [[ -z "$OUTPUT_PATH" ]]; then
        OUTPUT_PATH="$1"
      fi
      ;;
  esac
  shift
done

# Helper: get ovpn path by username (search priority: OVPN_OUTPUT_DIR > script dir > /root > cwd)
get_ovpn_path() {
  local name="$1"
  if [[ -n "${OVPN_OUTPUT_DIR:-}" && -f "${OVPN_OUTPUT_DIR}/${name}.ovpn" ]]; then
    echo "${OVPN_OUTPUT_DIR}/${name}.ovpn"
    return
  fi
  local script_dir ovpn
  script_dir="$(dirname "$OPENVPN_SCRIPT")"
  ovpn="$script_dir/${name}.ovpn"
  if [[ -f "$ovpn" ]]; then
    echo "$ovpn"
    return
  fi
  if [[ -f "/root/${name}.ovpn" ]]; then
    echo "/root/${name}.ovpn"
    return
  fi
  if [[ -f "./${name}.ovpn" ]]; then
    echo "./${name}.ovpn"
    return
  fi
  if [[ -f "${name}.ovpn" ]]; then
    echo "${name}.ovpn"
    return
  fi
  echo ""
}

# Helper: after generating, move ovpn file to OVPN_OUTPUT_DIR if set
move_ovpn_to_output_dir() {
  local name="$1"
  local src_ovpn
  src_ovpn="$(get_ovpn_path "$name")"
  if [[ -n "${OVPN_OUTPUT_DIR:-}" && -f "$src_ovpn" ]]; then
    mkdir -p "$OVPN_OUTPUT_DIR"
    mv "$src_ovpn" "$OVPN_OUTPUT_DIR/"
  fi
}

case "$CMD" in
  add)
    # Add user with or without private key password
    if [[ -z "$USER" ]]; then print_usage; fi
    export AUTO_INSTALL="y"
    export CLIENT="$USER"
    if [[ -n "$USER_PASS" ]]; then
      export PASS="2"
      export USER_PASS="$USER_PASS"
    else
      export PASS="1"
    fi
    bash "$OPENVPN_SCRIPT" --add
    move_ovpn_to_output_dir "$USER"
    ;;
  revoke)
    # Revoke user
    if [[ -z "$USER" ]]; then print_usage; fi
    export AUTO_INSTALL="y"
    export CLIENT="$USER"
    bash "$OPENVPN_SCRIPT" --remove
    ;;
  list)
    # List all users
    bash "$OPENVPN_SCRIPT" --list
    ;;
  regen)
    # Revoke and re-add user, password optional
    if [[ -z "$USER" ]]; then print_usage; fi
    export AUTO_INSTALL="y"
    export CLIENT="$USER"
    bash "$OPENVPN_SCRIPT" --remove || true
    if [[ -n "$USER_PASS" ]]; then
      export PASS="2"
      export USER_PASS="$USER_PASS"
    else
      export PASS="1"
    fi
    bash "$OPENVPN_SCRIPT" --add
    move_ovpn_to_output_dir "$USER"
    ;;
  show)
    # Print .ovpn config to stdout
    if [[ -z "$USER" ]]; then print_usage; fi
    ovpn_path=$(get_ovpn_path "$USER")
    if [[ -z "$ovpn_path" || ! -f "$ovpn_path" ]]; then
      echo "Config for user '$USER' not found."
      exit 3
    fi
    cat "$ovpn_path"
    ;;
  export)
    # Export .ovpn config to file
    if [[ -z "$USER" || -z "$OUTPUT_PATH" ]]; then print_usage; fi
    ovpn_path=$(get_ovpn_path "$USER")
    if [[ -z "$ovpn_path" || ! -f "$ovpn_path" ]]; then
      echo "Config for user '$USER' not found."
      exit 3
    fi
    cp "$ovpn_path" "$OUTPUT_PATH"
    echo "Exported $USER.ovpn to $OUTPUT_PATH"
    ;;
  *)
    print_usage
    ;;
esac

