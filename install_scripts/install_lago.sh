#!/bin/bash -xe

REPONAME="ovirt-system-tests"
REPOURL="https://gerrit.ovirt.org"

check_virtualization() {
  if dmesg | grep -q 'kvm: disabled by BIOS'; then
      echo "Please enable virtualization in BIOS"
      exit 1
  else
      echo "Virtualization extension is enabled"
  fi
}

check_cpu_man() {
  if lscpu | grep -q 'Model name:\s*Intel'; then
    echo intel
  else
    echo amd
  fi
}

enable_nested() {
  local cpu_man=$(check_cpu_man)
  local is_enabled=$(cat /sys/module/kvm_"$cpu_man"/parameters/nested)
  if [[ "$is_enabled" == 'N' ]]; then
      echo "Enabling nested virtualization..."
      echo "options kvm-$cpu_man nested=y" >> /etc/modprobe.d/kvm-"$cpu_man".conf
      echo "Please restart and rerun installation"
      exit 1
  else
      echo "Nested virtualization is enabled"
  fi
}

install_lago() {
    echo "Installing lago"
    yum install -y python-lago python-lago-ovirt
}

install_dependencies() {
    echo "Installing additional packages"
    yum install -y virt-viewer
}

add_lago_repo() {
    if ! grep -q "Fedora" /etc/redhat-release; then
        yum -y install epel-release
        local DISTRO=el
    else
        local DISTRO=fc
    fi
    echo "Configuring repos"
    cat > /etc/yum.repos.d/lago.repo <<EOF
[lago]
baseurl=http://resources.ovirt.org/repos/lago/stable/0.0/rpm/${DISTRO}\$releasever
name=Lago
enabled=1
gpgcheck=0

[ci-tools]
baseurl=http://resources.ovirt.org/repos/ci-tools/${DISTRO}\$releasever
name=ci-tools
enabled=1
gpgcheck=0
EOF
}

post_install_conf_for_lago() {
    echo "Configuring permissions"
    if [[ "$user" != "root" ]]; then
        usermod -a -G lago "$user"
        usermod -a -G qemu "$user"
        chmod g+x "/home/$user"
    else
        chmod g+x "/root"
    fi

    usermod -a -G "$user" qemu
}

enable_libvirt() {
    echo "Starting libvirt"
    systemctl restart libvirtd
    systemctl enable libvirtd
}

run_suite() {
    sudo -u "$user" bash <<EOF
if [[ ! "$suite" ]]; then
    exit 0
fi

echo "Running $REPONAME"
# clone or pull if already exist
if [[ -d "$REPONAME" ]]; then
    cd "$REPONAME"
    git pull "$REPOURL"/"$REPONAME"
else
    git clone "$REPOURL"/"$REPONAME" &&
    cd "$REPONAME"
fi
# check if the suite exists
if [[ "$?" == "0" ]] && [[ -d "$suite" ]]; then
    ./run_suite.sh "$suite"
else
    echo "Suite $suite wasn't found"
    exit 1
fi
EOF
}

print_help() {
  cat<<EOH
Usage: $0 user_name [suite_to_run]

Will install Lago and then clone oVirt system tests to the
current directory and run suite_to_run

The required permissions to run lago will be given to user_name.

If suite_to_run isn't specified Lago will be installed and no
suite will be run.
EOH
}

check_input() {
    id -u "$1" > /dev/null ||
    {
        echo "User $1 doesn't exist"
        print_help
        exit 1
    }
}

main() {
    check_input "$1"
    user="$1"
    suite="$2"
    check_virtualization
    enable_nested
    add_lago_repo
    install_lago
    install_dependencies
    post_install_conf_for_lago
    enable_libvirt
    run_suite
}

main "$@"
