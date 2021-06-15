#!/bin/sh -e
echo "Which architure do you prefer? (arm64 or amd64) ..."
read ARCH

VERSION=1.1.2
RELEASE=node_exporter-${VERSION}.linux-${ARCH}

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

_install_curl () {
    if [ -x "$(command -v curl)" ]; then
        return
    fi

    if [ -x "$(command -v apt-get)" ]; then
        apt-get update
        apt-get -y install curl
    elif [ -x "$(command -v yum)" ]; then
        yum -y install curl
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

if grep -q "prometheus" /etc/group    then
    echo "group prometheus existed"
else
    groupadd --system prometheus
    echo "added group prometheus"
fi

if id "prometheus" &>/dev/null;    then
    echo 'user prometheus found'
else
    useradd -s /sbin/nologin --system -g prometheus prometheus
    echo 'added user prometheus'
fi

touch /etc/systemd/system/node_exporter.service

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
ExecStart=/usr/bin/node_exporter

SyslogIdentifier=node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter
    echo "node_expterter is running at port 9100"
else
    echo "No known service management found" >&2;
    exit 1;
fi
