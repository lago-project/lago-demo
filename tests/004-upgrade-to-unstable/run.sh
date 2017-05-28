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

function switch_unstable {
    local dist_type
    dist_type=$(/usr/lib/rpm/redhat/dist.sh  --disttype)
    cat >> /etc/yum.repos.d/lago-unstable.repo << EOF
[lago-unstable]
baseurl=http://resources.ovirt.org/repos/lago/unstable/0.0/latest/rpm/$dist_type\$releasever
name=Lago
enabled=1
gpgcheck=0
EOF
    rm -rf /etc/yum.repos.d/lago.repo
    yum clean all
    }

function update_lago
{

    rpm -q lago
    rpm -q lago-ovirt
    lago --version
    yum update -y lago lago-ovirt
    lago --version
    rpm -q lago
    rpm -q lago-ovirt
}


function main() {
    switch_unstable
    update_lago
    start_vm "$USERNAME"
    start_vm "$SECONDARY_USER"
}

main "$@"
