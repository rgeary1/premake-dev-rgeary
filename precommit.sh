#!/bin/bash

# Run this before committing changes to ninja or premake

if [[ "$OS_VERSION" == "" ]]; then
	export OS_VERSION=$(uname -r | tr -d ' ')
fi

dir=$(dirname $0)
$dir/buildPremake.sh -n --toolset=gcc
cp $dir/build.ninja $dir/build.ninja.default
cp $dir/buildedges.ninja $dir/buildedges.ninja.default
sed -i "s,$OS_VERSION,OS_VERSION,g" $dir/buildedges.ninja.default

