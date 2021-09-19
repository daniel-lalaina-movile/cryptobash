#!/usr/bin/env bash

# https://github.com/daniel-lalaina-movile/cryptobash

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
cd $script_dir

if echo "$@" |grep -Eq  "overview.*[0-9]"; then
 docker run -d cryptobash "$@"
else
 docker run cryptobash "$@"
fi

