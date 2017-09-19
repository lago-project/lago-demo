#!/bin/bash -ex

readonly RUN_DIR="$(dirname "${BASH_SOURCE[0]}")"
readonly USERNAME="dummy_user"

function check_services() {
    systemctl is-active libvirtd
}

function virt_checks() {
    # just debug info
    getfacl /dev/kvm
    # virt-host-validate will exit with 1 on warnings too
    virt-host-validate || true
    libguestfs-test-tool
}

function _check_ovirt_sdk4() {
    local username
    username="$1"
    sudo su "$username" -l << EOF
bash -ex << EOS
python -c 'import ovirtsdk4; from ovirtsdk4 import version; print version.VERSION'
EOS
EOF
}

function check_ovirt_sdk4() {
    # Remove once sdk4 is available for fc2[56]
    local distro_str=$(rpm -E "%{?dist}")

    if [[ $distro_str =~ ^.fc2[56]$ ]]; then
        echo "oVirt SDK v4 isn't available on fc2[56], skipping"
        return
    fi

    _check_ovirt_sdk4 "$1"
}

function main() {
    check_services
    virt_checks
    check_ovirt_sdk4 "$USERNAME"
}

main "$@"
