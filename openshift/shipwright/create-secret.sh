#!/usr/bin/env bash

set -o pipefail -euf

PASSWORD=${1:-}

usage() {
    echo "Need to provide a password"
    exit 1
}

[ -z "$PASSWORD" ] && usage

oc create secret docker-registry tosmi-quay \
  --docker-server=quay.io \
  --docker-username=tosmi+tosmipush  \
  --docker-password="$PASSWORD" \
  --docker-email="toni@redhat.com"
