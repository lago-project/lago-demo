#!/bin/bash -ex

readonly RUN_DIR="$(dirname "${BASH_SOURCE[0]}")"
readonly USERNAME="dummy_user"

function check_sdk4() {
    local username
    username="$1"
    sudo su "$username" -l << EOF
bash -ex << EOS
python -c 'import ovirtsdk4; from ovirtsdk4 import version; print version.VERSION'
EOS
EOF
}

function main() {
    check_sdk4 "$USERNAME"
}

main "$@"
