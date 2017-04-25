#!/bin/bash -ex

readonly RUN_DIR="$(dirname "${BASH_SOURCE[0]}")"

function check_services() {
    systemctl is-active libvirtd
    systemctl is-active firewalld
}

function main() {
    check_services || exit $?
}

main "$@"
