#!/usr/bin/env bash

set -euo pipefail

gpg --import <<< "$SIGNING_KEY"
key_id="$(gpg --list-secret-keys | grep -A 1 sec | tail -n 1 | sed -r 's/(^\s*|\s*$)//g')"
echo "ID: $key_id"
repo-add -s -k "$key_id" /repo-packages/pschichtel.db.tar.gz /repo-packages/*.pkg.tar.zst

