#!/bin/bash -ex

# export LIBGUESTFS_BACKEND=direct
# export LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1

init_file_dir="${1:?}"
init_file_name="${2:?}"
log_dir="${3:?}"
log_path="${log_dir}/${0##*/}-$(whoami)-lago.log"

echo "$PWD"
mkdir -p "$log_dir"

cd "$init_file_dir"

lago shutdown
lago start
echo "Version before upgrade"
lago shell nested 'cat /tmp/lago_version.txt'
echo "Version after upgrade"
lago --version 2>&1
sudo cp .lago/default/logs/lago.log "$log_path"
lago destroy --yes
