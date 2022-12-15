#! /bin/bash

set -eo pipefail

_log_message() {
    [[ -t 0 ]] && echo -ne "\e[1m\e[3${1}m" || true
    shift
    echo "$@"
    [[ -t 0 ]] && echo -ne "\e[0m" || true
}

log() {
    _log_message 3 "$@"
}

error() {
    _log_message 1 "Error: $*"
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

case "$distro" in
    ubuntu|debian)
        check_package() {
            apt info "$1" &>/dev/null
        }
        install_package() {
            sudo apt install "$1"
        }
        ;;
    opensuse)
        check_package() {
            zypper search -x "$1" &>/dev/null
        }
        install_package() {
            sudo zypper install "$1"
        }
        ;;
    fedora)
        check_package() {
            dnf info "$1" &>/dev/null
        }
        install_package() {
            sudo dnf install "$1"
        }
        ;;
    centos)
        check_package() {
            yum info "$1" &>/dev/null
        }
        install_package() {
            yum install "$1"
        }
        ;;
    *)
        error "unsupported distro: $distro"
        exit 6
        ;;
esac

packages_not_found=()

for file_browser in "${file_browsers[@]}"; do
    log "Looking for extension package for file browser $file_browser on distro $distro..."

    upstream_package=owncloud-client-"$file_browser"

    case "$distro" in
        ubuntu|debian)
            distro_package="$file_browser"-owncloud
            ;;
        # CentOS doesn't provide a distro package, on Fedora/openSUSE, it uses the same name as our upstream package
        opensuse|fedora|centos)
            ;;
        centos)
            distro_package=
            ;;
    esac

    # always prefer to install upstream package if available
    package_found=

    for package in "$upstream_package" "$distro_package"; do
        if check_package "$package"; then
            package_found="$package"
        fi
    done

    if [[ "$package_found" == "" ]]; then
        error "could not find suitable package"
        packages_not_found+=("$package")
        continue
    fi

    log "Installing package $package_found..."
    (set -x && install_package "$package_found") || error "installation canceled"
done

if [[ "${#packages_not_found[@]}" -gt 0 ]]; then
    log
    error "packages ${packages_not_found[*]} could not be found"
    log "You might want to set up ownCloud's repository for your distribution."
    log "See https://owncloud.com/desktop-app/ for more information."
    exit 8
fi
