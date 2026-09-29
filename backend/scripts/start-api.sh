#!/bin/sh
set -eu
export PROMETHEUS_MULTIPROC_DIR=/tmp/flow-metrics
mkdir -p "$PROMETHEUS_MULTIPROC_DIR"
# This directory belongs only to this container's metrics files.
find "$PROMETHEUS_MULTIPROC_DIR" -type f -name '*.db' -delete
exec gunicorn app.main:app -c gunicorn.conf.py
