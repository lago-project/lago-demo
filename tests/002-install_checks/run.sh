#!/bin/bash -ex

readonly RUN_DIR="$(dirname "${BASH_SOURCE[0]}")"
readonly USERNAME="dummy_user"

function check_services() {
    systemctl is-active libvirtd
    systemctl is-active firewalld
}

function virt_checks() {
    # just debug info
    getfacl /dev/kvm
    # virt-host-validate will exit with 1 on warnings too
    virt-host-validate || true
    libguestfs-test-tool
}

function check_ovirt_sdk4() {
    local username
    username="$1"
    sudo su "$username" -l << EOF
bash -ex << EOS
python -c 'import ovirtsdk4; from ovirtsdk4 import version; print version.VERSION'
EOS
EOF
}

function main() {
    check_services
    virt_checks
    check_ovirt_sdk4 "$USERNAME"
}

main "$@"
