#!/bin/bash -xe

#Let's review the install script

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

add_lago_repo() {
    echo "Configuring repos"
    local DIST=$(uname -r | sed -r  's/^.*\.([^\.]+)\.[^\.]+$/\1/')
    cat > /etc/yum.repos.d/lago.repo <<EOF
[lago]
baseurl=http://resources.ovirt.org/repos/lago/stable/0.0/rpm/$DIST
name=Lago
enabled=1
gpgcheck=0

[ci-tools]
baseurl=http://resources.ovirt.org/repos/ci-tools/$DIST
name=ci-tools
enabled=1
gpgcheck=0
EOF

    if ! grep -q "Fedora" /etc/redhat-release; then
        cat > /etc/yum.repos.d/epel.repo <<EOF
[epel]
name=epel
mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=epel-7&arch=x86_64
gpgkey=https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7Server
EOF
    fi
}

post_install_conf_for_lago() {
    echo "Configuring permissions"
    # if not root
    if [[ "$user" != "root" ]]; then
        usermod -a -G lago "$user"
        usermod -a -G qemu "$user"
    fi

    usermod -a -G "$user" qemu
    chmod g+x "/home/$user"
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
    post_install_conf_for_lago
    enable_libvirt
    run_suite
}

main "$@"
