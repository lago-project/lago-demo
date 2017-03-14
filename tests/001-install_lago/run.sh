#!/bin/bash -ex

readonly RUN_DIR="$(dirname "${BASH_SOURCE[0]}")"
readonly USERNAME="dummy_user"
readonly CUSTOM_HOME="custom_home"
readonly INSTALL_SCRIPT="$RUN_DIR/install_lago.sh"

function setup_user() {
    local username custom_home
    username="$1"
    custom_home="$2"
    mkdir -p "/home/$custom_home"
    useradd -d "/home/$custom_home/$username" "$username"
    echo "$username ALL=(ALL) NOPASSWD:ALL" | (EDITOR="tee -a" visudo)
}

function main() {
    setup_user "$USERNAME" "$CUSTOM_HOME" || exit $?
    sudo su "$USERNAME" -l -c "sudo $INSTALL_SCRIPT --user $USERNAME" || exit $?
}

main "$@"
