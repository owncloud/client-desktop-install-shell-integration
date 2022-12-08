# Install ownCloud Linux Shell Extensions

The script provided within this repository helps users install the most suitable shell extensions for their Linux desktop system.


## Quickstart (using `--auto` mode)

The easiest way to install shell extensions suitable for your system is to copy the following line into a terminal on your computer and hit the Enter key:

```sh
curl -s https://raw.githubusercontent.com/owncloud/client-desktop-install-shell-integration/main/install-extensions.sh | bash -s - --auto

# if the command reports "curl: command not found", you can try the following command:
wget -q -O - https://raw.githubusercontent.com/owncloud/client-desktop-install-shell-integration/main/install-extensions.sh | bash -s - --auto

# if this command fails at well, you will have to install either the `curl` or `wget` package on your system using your system's package manager
# consult your operating system's manual for more information
```

In `--auto` mode, the script will automatically detect your operating system as well as supported file browsers you have installed on your system and install the required packages using your system's package manager.


## Manual usage

In case you feel uncomfortable running random scripts downloaded from the Internet (and, really, you should!), you can run the script manually.

First, [download the script from GitHub](https://raw.githubusercontent.com/owncloud/client-desktop-install-shell-integration/main/install-extensions.sh). Next, run it once to see the help text (optionally, you can pass `--help`):

```
curl -O https://raw.githubusercontent.com/owncloud/client-desktop-install-shell-integration/main/install-extensions.sh

# or, if curl is not installed, but wget is available:
wget https://raw.githubusercontent.com/owncloud/client-desktop-install-shell-integration/main/install-extensions.sh

# making it executable is optional
chmod +x install-extensions.sh

# see help text
bash install-extensions.sh
```

Currently, the following options are supported:

- `--auto`: automatically detect distribution and installed file browsers and install required packages
- `-h/--help`: display help text

If `--auto` is not used, you need to provide the following required parameters:

- `distro`: name of the distribution (currently supported values: `ubuntu debian opensuse fedora centos`)
- `file browers`: name of a supported file browser (can be specified more than once, usually equivalent to both the name of the executable as well as the system package)



## How the script works

The script prefers to install packages provided by ownCloud's Linux repositories, otherwise falls back to the distribution packages.

If none of these packages can be found or are deemed incompatible with the installed client, the script will ask you to use the official ownCloud Linux repositories. Please [follow the guide](https://doc.owncloud.com/desktop/3.0/installing.html#native-installation) to add the repository. Note that you do not have to install packages, you just need to add the repository. Then, you can call the script again and have it install the right packages.

You can re-run this script at any time to install extensions for newly installed file browsers. If no changes are required, the script won't perform any changes.


### Updates

Updates to the shell extensions are handled by your system's package manager, just like any other regular package.


## Security

See the [Security Aspects](https://doc.owncloud.com/ocis/next/security/security.html) for a general overview of security related topics.
If you find a security issue, please contact [security@owncloud.com](mailto:security@owncloud.com) first.


## Copyright

```console
Copyright (c) 2022 ownCloud GmbH <https://owncloud.com>
```
