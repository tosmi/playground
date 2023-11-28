#!/bin/bash

# shellcheck disable=SC3040
set -euf -o pipefail

oc exec falco-test-pod ls -l
oc rsh falco-test-pod -- echo bla > /tmp/bla
oc rsh falco-test-pod -- ls -l
