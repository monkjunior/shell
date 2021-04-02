#!/bin/sh -e
VERSION=1.1.2
RELEASE=node_exporter-${VERSION}.linux-arm64

_check_root () {
    if [ $(id -u) -ne 0 ]; then
        echo "Please run as root" >&2;
        exit 1;
    fi
}

_install_wget () {
    if [ -x "$(command -v wget)" ]; then
        return
    fi

    if [ -x "$(command -v apt-get)" ]; then
        apt-get update
        apt-get -y install wget
    elif [ -x "$(command -v yum)" ]; then
        yum -y install wget
    else
        echo "No known package manager found" >&2;
        exit 1;
    fi
}

_check_root
_install_curl

cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/${RELEASE}.tar.gz
tar xvf ${RELEASE}.tar.gz

mv ${RELEASE}/node_exporter /usr/bin/
rm -rf /tmp/${RELEASE}

groupadd --system prometheus
useradd -s /sbin/nologin --system -g prometheus prometheus

touch /etc/systemd/system/node_exporter.service /etc/sysconfig/node_exporter

if [ -x "$(command -v systemctl)" ]; then
    cat << EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
EnvironmentFile=/etc/sysconfig/node_exporter
ExecStart=/usr/bin/node_exporter $OPTIONS

SyslogIdentifier=node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    cat << EOF > /etc/sysconfig/node_exporter
OPTIONS="--collector.textfile.directory /var/lib/node_exporter/textfile_collector"
EOF
    systemctl daemon-reload
    systemctl enable node-exporter
    systemctl start node-exporter
else
    echo "No known service management found" >&2;
    exit 1;
fi
