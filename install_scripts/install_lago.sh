#!/bin/bash -e

readonly REPONAME="ovirt-system-tests"
readonly REPOURL="https://gerrit.ovirt.org"

readonly RHEL_CHANNELS=(
'rhel-7-server-rpms'
'rhel-7-server-optional-rpms'
'rhel-7-server-extras-rpms'
'rhel-7-server-rhv-4-mgmt-agent-rpms'
)

join_array() {
    local sep arr
    sep=','
    arr=("$@")
    res=$(IFS="$sep" ; echo "${arr[*]}")
    echo -E "$res"
}


print_rhel_notes() {
    echo "
Except the Lago repository, no repositories will be configured. Before running
the script, please ensure you have the below channels enabled:

$(join_array "${RHEL_CHANNELS[@]}")

After enabling those repositories, ensure also EPEL is enabled. If you want to
use the upstream repository, run:

  yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

  "
}

exit_error() {
    ! [[ -z "$1" ]] && echo "ERROR: $1"
    ! [[ -z "$2" ]] && exit "$2"
    exit 1
}

check_virtualization() {
  if dmesg | grep -q 'kvm: disabled by BIOS'; then
      echo "Please enable virtualization in BIOS"
      exit 1
  else
      echo "Virtualization extension is enabled"
  fi
}

get_cpu_vendor() {
  local vendor
  vendor=$(lscpu | awk '/Vendor ID/{print $3}')
  if [[ "$vendor" == 'GenuineIntel' ]]; then
      echo "intel"
  elif [[ "$vendor" == 'AuthenticAMD' ]]; then
      echo "amd"
  else
      exit_error "unrecognized CPU vendor: $vendor, only Intel/AMD are \
       supported"
  fi
}

check_nested() {
    local mod
    mod="kvm_$1"
    is_enabled=$(cat "/sys/module/$mod/parameters/nested")
    [[ "$is_enabled" == 'Y' ]] && return 0 || return 1
}

reload_kvm() {
    local mod
    mod="kvm-$1"
    (modprobe -r "$mod" && modprobe "$mod") && return 0 || return 1
}

enable_nested() {
    local vendor
    vendor=$(get_cpu_vendor)
    if ! check_nested "$vendor"; then
        echo "Enabling nested virtualization..."
        echo "options kvm-$vendor nested=y" >> "/etc/modprobe.d/kvm-$vendor.conf"
        (reload_kvm "$vendor" && check_nested "$vendor") || \
            exit_error "Nested virtualization is not enabled, please reboot \
        and re-run."
    fi
    echo "Nested virtualization is enabled"
}

install_lago() {
    echo "Installing lago"
    yum install -y lago lago-ovirt
}

add_lago_repo() {
    local distro
    local distro_str
    distro_str=$(rpm -E "%{?dist}") || exit_error "rpm command not found, only \
      RHEL/CentOS/Fedora are supported"
    echo "Detected distro is $distro_str"
    if [[ $distro_str =~ ^.el7(_[1-4])?$ ]]; then
        print_rhel_notes
        distro="el"
    elif [[ $distro_str == ".el7.centos" ]]; then
        distro="el"
        echo "Adding EPEL repository"
        yum install -y epel-release
        echo "Adding centos-qemu-ev repository"
        yum install -y centos-release-qemu-ev
    elif [[ $distro_str =~ ^.fc2[45]$ ]]; then
        distro="fc"
    else
        exit_error "Unsupported distro: $distro_str, Supported distros: \
            fc24, fc25, el7."
    fi
    echo "Adding Lago repositories.."
    cat > /etc/yum.repos.d/lago.repo <<EOF
[lago]
baseurl=http://resources.ovirt.org/repos/lago/stable/0.0/rpm/${distro}\$releasever
name=Lago
enabled=1
gpgcheck=0

[ci-tools]
baseurl=http://resources.ovirt.org/repos/ci-tools/${distro}\$releasever
name=ci-tools
enabled=1
gpgcheck=0
EOF
}

post_install_conf_for_lago() {
    echo "Configuring permissions"
    local user_home
    user_home=$(eval echo "~$INSTALL_USER")
    usermod -a -G lago,qemu "$INSTALL_USER"
    usermod -a -G "$INSTALL_USER" qemu
    chmod g+x "$user_home"
}

enable_libvirt() {
    echo "Enabling services"
    for service in 'libvirtd' 'virtlogd'; do
        (systemctl enable "$service" && \
            systemctl start "$service") || \
            exit_error "faild to start service $service"
    done
}

run_suite() {
    sudo -u "$INSTALL_USER" bash <<EOF
if [[ ! "$SUITE" ]]; then
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
if [[ "$?" == "0" ]] && [[ -d "$SUITE" ]]; then
    ./run_suite.sh "$SUITE"
else
    echo "Suite $SUITE wasn't found"
    exit 1
fi
EOF
}

print_help() {
  echo "
Usage: $0
$0 [options]

Lago installation script, supported distros: el7/fc24/fc25

Optionally, you can pass a '--suite' parameter, and it will also download and
execute one of the available oVirt system tests suites.

This script must be ran as root, but Lago should not be ran as root. The script
will attempt to detect the user that triggered the command. If you wish to
configure a different user, use '--user'.

CentOS notes
------------
Except the Lago repository, it will also install epel-release, which enables
EPEL repository, and centos-release-qemu-ev, which provides qemu-kvm-ev.


RHEL notes
----------
$(print_rhel_notes)


Optional arguments:
    -u,--user USERNAME
        Setup the necessary permissions for the specified user in order to run
        Lago. By default, it will use the output of 'logname'.

    -s,--suite SUITENAME
        Name of oVirt system tests suite to clone and execute, for available
        lists of suites, see:
            https://github.com/ovirt/ovirt-system-tests

    -h,--help
        Print this message.
"
}

parse_args() {
    local options
    options=$( \
        getopt \
            -o hu:s: \
            --long help,user:,suite: \
            -n 'install_lago.sh' \
            -- "$@" \
    )
    eval set -- "$options"
    while true; do
        case $1 in
            -u|--user)
                INSTALL_USER="$2"
                shift 2
                ;;
            -s|--suite)
                SUITE="$2"
                shift 2
                ;;
            -h|--help)
                print_help && exit 0
                ;;
            --)
                shift
                break
                ;;
        esac
    done
    if [[ -z "$INSTALL_USER" ]]; then
        INSTALL_USER=$(logname) || exit_error "failed running 'logname' to \
            detect the username. Try running with --user USERNAME"
        echo "detected user: $INSTALL_USER"
    fi
    id -u "$INSTALL_USER" > /dev/null || \
            exit_error "user: $INSTALL_USER does not exist."

    if [[ "$EUID" -ne 0 ]]; then
        exit_error "must be ran as root, see --help."
    fi

}

main() {
    parse_args "$@"
    check_virtualization
    enable_nested
    add_lago_repo
    install_lago
    post_install_conf_for_lago
    enable_libvirt
    echo "Finished installing and configuring Lago for user $INSTALL_USER."
    run_suite
}

main "$@"
