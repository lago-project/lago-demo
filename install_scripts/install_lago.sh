#!/bin/bash -xe


REPONAME="ovirt-system-tests"
REPOURL="https://gerrit.ovirt.org"

function check_virtualization() {
  if dmesg | grep 'kvm: disabled by BIOS'; then
      echo "Please enable virtualization in BIOS"
      exit 1
  else
      echo "Virtualization extension is enabled"
  fi
}

function enable_nested() {
  local is_enabled=$(cat /sys/module/kvm_intel/parameters/nested)
  if [[ $is_enabled == 'N' ]]; then
      echo "Enabling nested virtualization..."
      echo "options kvm-intel nested=y" >> /etc/modprobe.d/kvm-intel.conf
      echo "Please restart and rerun installation"
      exit 1
  else
      echo "Nested virtualization is enabled"
  fi
}

function install_lago() {
    echo "Installing lago"
    yum install -y python-lago python-lago-ovirt
}

function add_lago_repo() {
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

    if ! grep "Fedora" /etc/redhat-release; then
        cat > /etc/yum.repos.d/epel.repo <<EOF
[epel]
name=epel
mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=epel-7&arch=x86_64
gpgkey=https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7Server
EOF
    fi
}

function post_install_conf_for_lago() {
    echo "Configuring permissions"
    # if not root
    if [[ $user != "root" ]]; then
        usermod -a -G lago $user
        usermod -a -G qemu $user
    fi

    usermod -a -G "$user" qemu
    chmod g+x $HOME
}

function enable_libvirt() {
    echo "Starting libvirt"
    systemctl restart libvirtd
    systemctl enable libvirtd
}

function run_system_tests() {
    #if no suite supllied
    if [[ ! "$suite" ]]; then
        exit 0
    fi

    echo "Running "$REPONAME""
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
}

function print_help() {
  cat<<EOH
Usage: $0 user_name [suite_to_run]

Will install Lago and then clone oVirt system tests to the
current directory and run suite_to_run

The required permissions to run lago will be given to user_name.

If suite_to_run isn't specified Lago will be installed and no
suite will be run.
EOH
}

function check_input() {
    id -u "$1" > /dev/null ||
    {
        echo "User $1 doesn't exist"
        print_help
        exit 1
    }
}

function main() {
    check_input "$1"
    user="$1"
    suite="$2"
    check_virtualization
    enable_nested
    add_lago_repo
    install_lago
    post_install_conf_for_lago
    enable_libvirt
    run_system_tests
}

main "$@"
