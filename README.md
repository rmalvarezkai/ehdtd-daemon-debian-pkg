# ehdtd-daemon-debian-pkg
Script to create the Debian package for [ehdtd-daemon](https://github.com/rmalvarezkai/ehdtd_daemon).

## Disclaimer
I am not an expert in creating Debian packages. While this script works, it does not strictly adhere to Debian's standard packaging guidelines.

## Introduction
The ehdtd-daemon-debian-pkg is a Bash script designed to create a Debian package.

## Installation
```bash
git clone https://github.com/rmalvarezkai/ehdtd-daemon-debian-pkg
```

## Usage
```bash
cd ehdtd-daemon-debian-pkg
bash make-debian-package.sh [DIST_CODENAME] # Default DIST_CODENAME is the output from lsb_release -s -c # Only tested for bullseye and bookworm
```

### How to install deb package
1. Copy the .deb package to the server where it will be installed.
2. Execute the following command:
~~~
apt-get install /tmp/PATH_TO_DEB_FILE
~~~
3. Stop the ehdtd-daemon service:
~~~
systemctl stop ehdtd-daemon.service
~~~
4. Edit the configuration file /etc/ehdtd-daemon/ehdtd-daemon-config.yaml with the appropriate options.
5. Edit the file /etc/default/ehdtd-daemon and change the variable ENABLE=no to ENABLE=yes.
6. Start the ehdtd-daemon service:
~~~
systemctl start ehdtd-daemon.service
~~~

### Example
```bash
    apt-get install /tmp/ehdtd-daemon_0.1.8-b1~Debian~bullseye_amd64.deb
    systemctl stop ehdtd-daemon.service
    nano /etc/ehdtd-daemon/ehdtd-daemon-config.yaml
    rpl no yes /etc/default/ehdtd-daemon
    systemctl start ehdtd-daemon.service
```

After these steps, all data will be available in a PostgreSQL or MySQL database named ehdtd.


