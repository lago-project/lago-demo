#!/bin/bash -ex

readonly INIT_FILE='automation/lago-init.yaml'
readonly TESTS_PATH='/tmp'
readonly TIMEOUT="$((10 * 60))"

function set_params() {
    ! [[ -c "/dev/kvm" ]] && mknod /dev/kvm c 10 232
    export LIBGUESTFS_BACKEND=direct
    export LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1
    mkdir -p "$PWD/exported-artifacts"
}

function start_env() {
    lago --loglevel=debug --logdepth=5 init "$INIT_FILE"
    lago start && trap "cleanup" EXIT
    lago deploy
}


function copy_test_to_vm() {
    set -ex
    local vm test_name tests_path
    vm="$1"
    test_name="$2"
    tests_path="$3"
    lago copy-to-vm "$vm" "$PWD/tests/$test_name" "$tests_path/$test_name"
    lago copy-to-vm "$vm" "$PWD/install_scripts/install_lago.sh" \
        "$tests_path/$test_name/install_lago.sh"
    lago shell "$vm" -c "chmod +x $tests_path/$test_name/*.sh"
}

function run_tests() {
    set -ex
    local args vm tests_path tests
    args=("$@")
    # note: with bash > 4.3 we could use args[-1] in unset also.
    tests_path=${args[-1]} && unset "args[${#args[@]} -1]"
    vm=${args[-1]} && unset "args[${#args[@]} -1]"
    tests=(${args[@]})
    for test in "${tests[@]}"; do
        lago shell "$vm" -c "$tests_path/$test/run.sh |& \
            tee -a /var/log/test_$test.log; \
            exit \${PIPESTATUS[0]}"
    done
}


function get_vm_names() {
    local vms
    vms=$(lago --out-format=flat status |\
        grep -E "^VMs/(.*)/status: running$" |\
        awk -F'/' \{'print $2'\})
    echo "$vms"
}

function cleanup() {
    lago collect --output "$PWD/exported-artifacts/logs/test_logs"
    cp "$PWD/.lago/current/logs/lago.log" "$PWD/exported-artifacts/logs/test_logs/lago.log"
    lago destroy --yes
}

function main() {
    local vms
    set_params
    start_env

    vms=($(get_vm_names))
    tests=($(ls "$PWD/tests"))
    export -f copy_test_to_vm
    parallel --tagstring "{1}:copy_test:" --lb -k --halt now,fail=1 \
        copy_test_to_vm ::: "${vms[@]}" ::: "${tests[@]}" ::: "$TESTS_PATH"
    export -f run_tests
    parallel --timeout "$TIMEOUT" --tagstring "{-2}:run_tests:" --lb -k \
        --halt now,fail=1 \
        run_tests "${tests[@]}" ::: "${vms[@]}" ::: "$TESTS_PATH"
}

main

