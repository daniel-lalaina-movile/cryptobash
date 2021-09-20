#!/usr/bin/env bash

# https://github.com/daniel-lalaina-movile/cryptobash

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
cd $script_dir

latest() {
 latest=$(docker image ls |grep cryptobash |head -n1 |awk '{print $2}')
}

parameters="$@"

if echo "$parameters" |grep -Eq  "stop"; then
 for container in `docker ps |grep cryptobash |awk '{print $1}' 2>/dev/null`; do docker stop $container; done
 for image in `docker image ls |grep cryptobash |awk '{print $3}' |tail -n+2 2>/dev/null`; do docker rmi -f $image; done
 exit
fi

if [ -z $latest ]; then
 docker build -t cryptobash:cryptobash_$(date +%Y%m%d%H%M%S) .
 latest
fi

temp_dir=$(date +%Y%m%d%H%M%S)
mkdir $script_dir/temp/$temp_dir

# docker version compatibility
if docker run --help |grep -q "\-\-mount"; then
 mount="--mount source=$script_dir,target=/cryptobash"
elif docker run --help  |grep "\-v, \-\-volume list"; then
 mount="-v $script_dir:/cryptobash"
else
 echo "You are using some crazy docker version, please contact cryptobash project owner"
fi

if echo "$parameters" |grep -Eq  "overview.*telegram.*[0-9]"; then
 docker run -d $mount --restart unless-stopped cryptobash:$latest $temp_dir $parameters
else
 docker run -i $mount cryptobash:$latest $temp_dir $parameters
fi

