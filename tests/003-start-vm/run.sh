#!/bin/bash -ex

readonly RUN_DIR="$(dirname "${BASH_SOURCE[0]}")"
readonly USERNAME="dummy_user"
readonly SECONDARY_USER="dummy_user2"
readonly INIT_FILE="$RUN_DIR/init-nested"

function start_vm() {
    local username
    username="$1"
    sudo su "$username" -l << EOF
bash -ex << EOS
export LIBGUESTFS_BACKEND=direct
export LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1
lago --version
lago ovirt --help
lago init $INIT_FILE
lago start
lago shell nested -c 'hostname' && lago destroy --yes

EOS
EOF
}

function main() {
    start_vm "$USERNAME"
    start_vm "$SECONDARY_USER"
}

main "$@"
