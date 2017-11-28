#!/bin/bash -ex

readonly INIT_FILE='automation/lago-init.yaml'
readonly TESTS_PATH='/tmp'

set_params() {
    ! [[ -c "/dev/kvm" ]] && mknod /dev/kvm c 10 232
    # Uncomment for debugging libguestfs
    # export LIBGUESTFS_BACKEND=direct
    # export LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1
    mkdir -p "$PWD/exported-artifacts"
}

start_env() {
    lago --loglevel=debug --logdepth=5 init "$INIT_FILE"
    lago start
    lago deploy
    lago ansible_hosts > inventory
}

cleanup() {
    set +e
    lago collect --output "$PWD/exported-artifacts/logs/test_logs"
    cp "$PWD/.lago/current/logs/lago.log" "$PWD/exported-artifacts/logs/test_logs/lago.log"
    lago destroy --yes || force_cleanup
}

force_cleanup() {
    echo "Cleaning with libvirt"

    local domains=($( \
        virsh -c qemu:///system list --all --name \
        | egrep "^lago-vm-.+"
    ))
    local nets=($( \
        virsh -c qemu:///system net-list --all \
        | egrep -w "[[:alnum:]]{4}-.*" \
        | egrep -v "vdsm-ovirtmgmt" \
        | awk '{print $1;}' \
    ))

    for domain in "${domains[@]}"; do
        virsh -c qemu:///system destroy "$domain"
    done
    for net in "${nets[@]}"; do
        virsh -c qemu:///system net-destroy "$net"
    done

    echo "Cleaning with libvirt Done"
}

function main() {
    set_params
    start_env
    ansible-playbook \
        -u root \
        -i inventory \
        -v \
        test-playbook.yaml
}

trap "cleanup" EXIT
main
