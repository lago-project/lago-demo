#!/bin/bash -e

readonly REPONAME="ovirt-system-tests"
readonly REPOURL="https://gerrit.ovirt.org"
readonly LAGO_REPO_FILE="/etc/yum.repos.d/lago.repo"

# used for installing ovirt python sdk
readonly OVIRT_REPO="http://resources.ovirt.org/pub/ovirt-4.1/rpm/"
readonly OVIRT_REPO_FILE="/etc/yum.repos.d/ovirt-sdk.repo"

readonly RHEL_CHANNELS=(
'rhel-7-server-rpms'
'rhel-7-server-optional-rpms'
'rhel-7-server-extras-rpms'
'rhel-7-server-rhv-4-mgmt-agent-rpms'
)


if hash dnf &>/dev/null; then
    readonly PKG_MG="dnf"
else
    readonly PKG_MG="yum"
fi

function join_array() {
    local sep arr
    sep=','
    arr=("$@")
    res=$(IFS="$sep" ; echo "${arr[*]}")
    echo -E "$res"
}


function print_rhel_notes() {
    echo "

RHEL notes(None CSB)
------------------------
Except the Lago repository, no repositories will be configured. Before running
the script, please ensure you have the following channels enabled:

$(join_array "${RHEL_CHANNELS[@]}")

After enabling those repositories, ensure also EPEL is enabled. If you want to
use the upstream repository, run:

  yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

  "
}

function exit_error() {
    ! [[ -z "$1" ]] && echo "ERROR: $1"
    ! [[ -z "$2" ]] && exit "$2"
    exit 1
}

function check_virtualization() {
  if dmesg | grep -q 'kvm: disabled by BIOS'; then
      echo "Please enable virtualization in BIOS"
      exit 1
  else
      echo "Virtualization extension is enabled"
  fi
}

function get_cpu_vendor() {
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

function check_nested() {
    local mod
    mod="kvm_$1"
    is_enabled=$(cat "/sys/module/$mod/parameters/nested")
    [[ "$is_enabled" == 'Y' ]] && return 0 || return 1
}

function reload_kvm() {
    local mod
    mod="kvm-$1"
    echo "Reloading kvm kernel module"
    (modprobe -r "$mod" && \
        modprobe -r "kvm" && \
        modprobe "kvm" && \
        modprobe "$mod" ) && \
        return 0 || \
        return 1
}

function enable_nested() {
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

function install_lago() {
    echo "Installing lago"
    "$PKG_MG" install -y lago lago-ovirt
}

function install_ovirt_sdk() {
    echo "Installing python-ovirt-engine-sdk4"
    "$PKG_MG" install -y python-ovirt-engine-sdk4
}

function add_lago_repo() {
    local distro
    distro="$1"
    if ! [[ -f "$LAGO_REPO_FILE" ]]; then
        cat > "$LAGO_REPO_FILE" <<EOF
[lago]
baseurl=http://resources.ovirt.org/repos/lago/unstable/0.0/latest/rpm/${distro}\$releasever
name=Lago
enabled=1
gpgcheck=0

[ci-tools]
baseurl=http://resources.ovirt.org/repos/ci-tools/${distro}\$releasever
name=ci-tools
enabled=1
gpgcheck=0
EOF
    else
        echo "$LAGO_REPO_FILE already exists, not adding."
    fi

}

function add_ovirt_repo() {
    local distro
    distro="$1"

    if ! [[ -f "$OVIRT_REPO_FILE" ]]; then
        cat > "$OVIRT_REPO_FILE" <<EOF
[ovirt-41]
baseurl=$OVIRT_REPO/$distro\$releasever
name=ovirt
enabled=1
gpgcheck=0
includepkgs=python-ovirt-engine-sdk4
EOF
    else
        echo "$OVIRT_REPO_FILE already exists, not adding."
    fi
}

function detect_distro() {
    local distro_str
    distro_str=$(rpm -E "%{?dist}") || exit_error "rpm command not found, only \
      RHEL/CentOS/Fedora are supported"
    echo "$distro_str"
}

function add_repos() {
    local distro_str
    distro_str="$1"
    if [[ $distro_str =~ ^.el7(ev)?(_[1-4])?$ ]]; then
        print_rhel_notes
        distro="el"
    elif [[ $distro_str == ".el7.centos" ]]; then
        distro="el"
        "$PKG_MG" install -y epel-release
        "$PKG_MG" install -y centos-release-qemu-ev
        add_ovirt_repo "$distro"
    elif [[ $distro_str =~ ^.fc2[456]$ ]]; then
        distro="fc"
        # ovirt python sdk is not available on fc25/26
        if [[ $distro_str == ".fc24" ]]; then
            add_ovirt_repo "$distro"
        fi
    else
        exit_error "Unsupported distro: $distro_str, Supported distros: \
            fc24, fc25, fc26, el7."
    fi
    add_lago_repo "$distro"
}


function post_install_conf_for_lago() {
    echo "Configuring permissions"
    local user_home
    user_home=$(eval echo "~$INSTALL_USER")
    usermod -a -G lago,qemu "$INSTALL_USER"
    usermod -a -G "$INSTALL_USER" qemu
    chmod g+x "$user_home"
}

function enable_service() {
    local service
    service="$1"
    (systemctl enable "$service" && \
     systemctl restart "$service") || \
            exit_error "faild to start service $service"
}

function enable_services() {
    enable_service "firewalld"
    enable_service "libvirtd"
    # see: https://bugzilla.redhat.com/show_bug.cgi?id=1290357
    systemctl cat "virtlogd.service" &> /dev/null && \
        enable_service "virtlogd"
}

function configure_ipv6_networking() {
    echo "net.ipv6.conf.all.accept_ra=2" >> "/etc/sysctl.conf"
    sysctl -p
}

function run_suite() {
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

function print_help() {
  echo "
Usage: $0
$0 [options]

Lago and Lago-ovirt installation script, supported distros: el7/fc24/fc25

Optionally, you can pass a '--suite' parameter, and it will also download and
execute one of the available oVirt system tests suites.

This script must be ran as root, but Lago should not be ran as root. The script
will attempt to detect the user that triggered the command. If you wish to
configure a different user, use '--user'.

CentOS notes
------------
Except the Lago repository, it will install epel-release, which enables
EPEL repository, centos-release-qemu-ev, which provides qemu-kvm-ev and the
oVirt repository, which provides the python oVirt engine SDK v4 package.


$(print_rhel_notes)


Optional arguments:
    -u,--user USERNAME
        Setup the necessary permissions for the specified user in order to run
        Lago. By default, it will use the output of 'logname'.

    -p,--permissions-only
        Only setup the necessary permissions for the user and exit. This must
        be called after Lago was already installed.

    -s,--suite SUITENAME
        Name of oVirt system tests suite to clone and execute, for available
        lists of suites, see:
            https://github.com/ovirt/ovirt-system-tests

    -h,--help
        Print this message.
"
}

function parse_args() {
    local options
    options=$( \
        getopt \
            -o hpu:s: \
            --long help,permissions-only,user:,suite: \
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
            -p|--permissions-only)
                readonly PERMS_ONLY=true
                shift 1
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

function main() {
    local distro_str
    parse_args "$@"
    if [[ "$PERMS_ONLY" == true ]]; then
        echo "Only configuring permissions for user $INSTALL_USER"
        post_install_conf_for_lago
        echo "Done."
        exit 0
    fi
    check_virtualization
    enable_nested
    distro_str="$(detect_distro)"
    add_repos "$distro_str"
    install_lago
    if ! [[ "$distro_str" =~ ^.fc2[56]$ ]]; then
        install_ovirt_sdk
    fi
    post_install_conf_for_lago
    reload_kvm "$(get_cpu_vendor)"
    enable_services
    configure_ipv6_networking
    echo "Finished installing and configuring Lago for user $INSTALL_USER."
    run_suite
}

main "$@"
