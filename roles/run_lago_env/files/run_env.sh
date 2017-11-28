#!/bin/bash -ex

# export LIBGUESTFS_BACKEND=direct
# export LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1

init_file_dir="$1"
init_file_name="$2"
template_repo="$3"
log_dir="$4"
log_path="${log_dir}/${0##*/}-$(whoami)-lago.log"

echo "$PWD"
mkdir -p "$log_dir"

cd "$init_file_dir"

lago init --template-repo-path "$template_repo" "$init_file_name"
lago start
lago shell nested -c 'hostname'
sudo cp .lago/default/logs/lago.log "$log_path"
lago destroy --yes
