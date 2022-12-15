#! /bin/bash

set -eo pipefail

_log_message() {
    [[ -t 0 ]] && echo -ne "\e[1m\e[3${1}m" || true
    shift
    echo "$@"
    [[ -t 0 ]] && echo -ne "\e[0m" || true
}

log() {
    _log_message 2 "$@"
}

error() {
    _log_message 1 "Error: $*"
}

warning() {
    _log_message 3 "Warning: $*"
}

show_usage() {
    log "Usage: bash $0 [--auto] [distro] [file browser...]"
    log
    log "Options:"
    log
    log "  --auto:        Automatically install extensions suitable for this distribution and the installed file browsers"
    log "  -h/--help:     Display this help text"
    log
    log "Positional parameters:"
    log "  distro:        Distribution to install packages for"
    log "  file browser:  File browser to install extension for"
    log "                 (can be specified more than once)"
    log
    log "Supported distributions: ubuntu debian fedora centos opensuse"
    log "Supported file browsers: caja dolphin nautilus nemo"
}

case "$1" in
    ""|-h|--help)
        show_usage
        exit 0
        ;;
    "--auto")
        if [[ "$2" != "" ]]; then
            error "--auto does not support additional parameters"
            show_usage
            exit 2
        fi

        if [[ ! -f /etc/os-release ]]; then
            error "could not detect distribution automatically"
            show_usage
            exit 3
        fi

        source /etc/os-release

        case "$ID" in
            ubuntu|debian|fedora|centos)
                distro="$ID"
                ;;
            opensuse*)
                distro=opensuse
                ;;
            *)
                error "failed to detect distribution from /etc/os-release"
                show_usage
                exit 4
                ;;
        esac
        ;;
    *)
        distro="$1"
        ;;
esac

# if a first parameter was provided, we need to skip it in our loop below (in case we should not auto detect)
[[ "$1" != "" ]] && shift

# if file browser  names are passed, these should be used, otherwise, we should detect them ourselves
file_browsers=()
if [[ "$1" != "" ]]; then
    file_browsers=("$@")
else
    for command in caja dolphin nautilus nemo; do
        if command -v "$command" &>/dev/null; then
            file_browsers+=("$command")
        fi
    done
fi

if [[ ${#file_browsers[@]} -eq 0 ]]; then
    error "could not detect any supported file browsers"
    show_usage
    exit 5
fi

for command in sudo pkexec; do
    if type "$command" &>/dev/null; then
        sudo_command=("$command")
        break
    fi
done

if [[ "$(id -u)" == 0 ]]; then
    # we need some "dummy" command, calling a subshell works reasonably well
    sudo_command=("sh", "-c")
fi

if [[ -z "$sudo_command" ]]; then
    error "sudo command not found and script not run as root"
    log
    log "This script needs root access to install packages."
    log "We highly recommend you to install sudo or pkexec to allow the script to selectively request privileges only where necessary."
    log "If this is not an option (or packages are not available), please re-run the entire script with root privileges."
    exit 6
fi

case "$distro" in
    ubuntu|debian)
        check_package() {
            apt info "$1" &>/dev/null
        }
        install_package() {
            "${sudo_command[@]}" apt install "$1"
        }
        ;;
    opensuse)
        check_package() {
            zypper search -x "$1" &>/dev/null
        }
        install_package() {
            "${sudo_command[@]}" zypper install "$1"
        }
        ;;
    fedora)
        check_package() {
            dnf info "$1" &>/dev/null
        }
        install_package() {
            "${sudo_command[@]}" dnf install "$1"
        }
        ;;
    centos)
        check_package() {
            yum info "$1" &>/dev/null
        }
        install_package() {
            "${sudo_command[@]}" yum install "$1"
        }
        ;;
    *)
        error "unsupported distro: $distro"
        exit 6
        ;;
esac

installed_packages=()
installation_failed=()

# small utility to check whether the first passed version number is greater than or equal to the second one
version_ge() {
    local newer_version
    newer_version="$(echo -e "$1\\n$2" | sort -V | tail -n1 | tr -d '\n')"
    [[ "$newer_version" == "$2" ]] && return 0
    return 1
}


for file_browser in "${file_browsers[@]}"; do
    log "Looking for extension package for file browser $file_browser on distro $distro..."

    upstream_package=owncloud-client-"$file_browser"

    debian_ubuntu_package="$file_browser"-owncloud

    distro_package=

    case "$distro" in
        ubuntu|debian)
            [[ "$distro" == "ubuntu" ]] && version_to_check=22.04 || version_to_check=12

            if version_ge "$VERSION_ID" "$version_to_check"; then
                warning "distro-provided package is incompatible, skipping"
            else
                distro_package="$debian_ubuntu_package"
            fi
            ;;
        # CentOS doesn't provide a distro package, on Fedora/openSUSE, it uses the same name as our upstream package
        opensuse|fedora|centos)
            ;;
    esac

    # always prefer to install upstream package if available
    package_found=

    for package in "$upstream_package" "$distro_package"; do
        if [[ "$package" == "" ]]; then
            continue
        fi

        if check_package "$package"; then
            package_found="$package"

            if install_package "$package"; then
                installed_packages+=("$package")
            else
                installation_failed+=("$package")
            fi

            # we just try to install one of them
            break
        fi
    done

    if [[ "$package_found" == "" ]]; then
        error "could not find suitable package for file browser $file_browser"
        packages_not_found+=("$package")
        continue
    fi

    log "Installing package $package_found..."
    (set -x && install_package "$package_found") || error "installation canceled"
done

has_error=0
if [[ "${#installed_packages[@]}" -gt 0 ]]; then
    log
    log "the following packages were installed successfully: ${installed_packages[*]}"
else
    log
    error "could not find any compatible packages to install"
    has_error=1
fi

if [[ "${#installation_failed[@]}" -gt 0 ]]; then
    log
    error "the following packages failed to install properly: ${installed_packages[*]}"
    log "See the log above for more information"
    has_error=1
fi

if [[ "$has_error" != 0 ]]; then
    log
    log "You might want to set up ownCloud's repository for your distribution."
    log "See https://owncloud.com/desktop-app/ for more information."
    exit 8
fi
