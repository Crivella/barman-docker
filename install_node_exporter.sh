#!/bin/bash

set -exo pipefail
shopt -s nullglob

echo "Installing node-exporter"
mkdir -p /node-exporter
cd /node-exporter

DESTDIR=node_exporter-${NODE_EXPORTER_VERSION}.${NODE_EXPORTER_ARCH}
FILE=${DESTDIR}.tar.gz
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${FILE}
tar -zxvf ${FILE}
ln -s /node-exporter/${DESTDIR}/node_exporter /node-exporter/node-exporter