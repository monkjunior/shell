#!/bin/sh -e
VERSION=0.12.1
RELEASE=mysqld_exporter-${VERSION}.linux-amd64

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
wget https://github.com/prometheus/mysqld_exporter/releases/download/v${VERSION}/${RELEASE}.tar.gz
tar xvf ${RELEASE}.tar.gz

mv ${RELEASE}/mysqld_exporter /usr/bin/
chmod +x /usr/bin/mysqld_exporter
rm -rf /tmp/${RELEASE}

groupadd --system prometheus
useradd -s /sbin/nologin --system -g prometheus prometheus

touch /etc/systemd/system/mysqld_exporter.service

if [ -x "$(command -v systemctl)" ]; then
    cat << EOF > /etc/systemd/system/mysqld_exporter.service
[Unit]
Description=Prometheus MySQL Exporter
After=network.target
User=prometheus
Group=prometheus

[Service]
Type=simple
Restart=always
ExecStart=/usr/bin/mysqld_exporter \
--config.my-cnf /etc/.mysqld_exporter.cnf \
--collect.global_status \
--collect.info_schema.innodb_metrics \
--collect.auto_increment.columns \
--collect.info_schema.processlist \
--collect.binlog_size \
--collect.info_schema.tablestats \
--collect.global_variables \
--collect.info_schema.query_response_time \
--collect.info_schema.userstats \
--collect.info_schema.tables \
--collect.perf_schema.tablelocks \
--collect.perf_schema.file_events \
--collect.perf_schema.eventswaits \
--collect.perf_schema.indexiowaits \
--collect.perf_schema.tableiowaits \
--collect.slave_status \
--web.listen-address=0.0.0.0:9104

[Install]
WantedBy=multi-user.target
EOF

#     cat << EOF > /etc/.mysqld_exporter.cnf
# [client]
# user=mysqld_exporter
# password=<your password>
# host=<your host>
# EOF

    systemctl daemon-reload
    systemctl enable mysqld_exporter
    systemctl start mysqld_exporter
    echo "mysqld_expterter is running at port 9104"
else
    echo "No known service management found" >&2;
    exit 1;
fi
