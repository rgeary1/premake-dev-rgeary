#!/bin/bash

if [[ "$TMP_DIR" == "" ]]; then
	export TMP_DIR=/tmp/$USER
	mkdir -p $TMP_DIR
fi

if [[ "$OS_VERSION" == "" ]]; then
	export OS_VERSION="$(uname -r | tr -d ' ')"
fi

# Exit with code 2 on Ctrl-C
trap "exit 2" SIGINT

#
# Blocking wait if buildPremake is called simultaneously
#
trap "rm -f $TMP_DIR/makeluasockets $TMP_DIR/buildingPremake.lock" 0

while [[ -f "$TMP_DIR/buildingPremake.lock" ]]; do
	echo "Another process is building Premake, sleeping..."
	sleep 10
done
touch $TMP_DIR/buildingPremake.lock


##DEBUG
if [[ "$PREMAKE_PRERUN" != "" ]]; then
	$PREMAKE_PRERUN
	rv=$?
	if [[ $rv != 0 ]]; then
		exit $rv
	fi
fi

which readlink 2>&1 > /dev/null
if [[ $? == 0 ]]; then
	premakeDir=$(readlink -f $(dirname $0) )
else
	premakeDir=$(dirname $0)
fi
premake="$premakeDir/bin/$OS_VERSION/Debug/premake4 --scripts=$premakeDir/src"
systemScript="--systemScript=$premakeDir/premake-system.lua"
hashFile=$premakeDir/hash.$OS_VERSION.tmp
cd $premakeDir
touch $premakeDir/src/host/scripts.c

forceBuild=0
threads="-j16"
verbose=
args=()

for arg in $@; do
	if [[ "$arg" == "-v" ]]; then verbose=1;
	elif [[ "$arg" == "-f" ]]; then forceBuild=1;
	elif [[ "${arg:0:2}" == "-j" ]]; then threads=$arg;
	elif [[ "$arg" == "-d" ]]; then args+=("--debug");
	#elif [[ "${arg:0:9}" == "--toolset" ]]; then toolset=$arg
	else
		args+=($arg)
	fi
done
args+=($threads)

if [[ $verbose ]]; then
	echo "Building Premake"
fi

if [[ "$PREMAKE_PRERUN" == "" ]]; then
	find $premakeDir/obj -name '*.o.d' -exec rm {} \; > /dev/null 2>&1
fi

if [[ $forceBuild == 1 ]]; then
	(rm -rf $premakeDir/bin 
	 rm -rf $premakeDir/obj
	 #rm -rf $luasocketDir
	 rm *.ninja
	 rm .ninja_log) 2> /dev/null
fi

if [[ ! -f "$premakeDir/build.ninja" ]]; then
	cp $premakeDir/build.ninja.default $premakeDir/build.ninja
fi
cp $premakeDir/buildedges.ninja.default $premakeDir/buildedges.ninja
sed -i "s,OS_VERSION,$OS_VERSION,g" $premakeDir/buildedges.ninja

# Test if premake exists
if [[ ! -f "$premakeDir/bin/$OS_VERSION/Release/premake4" || ! -f "$premakeDir/bin/$OS_VERSION/Debug/premake4" ]]; then
	# Assume that ninja files in the depot are valid
	ninja -q -C $premakeDir $threads Debug
	result=$?
	if [[ $result != 0 ]]; then
		echo "Error building Premake : ninja bootstrap of premake failed"
		exit $result
	fi
fi
	
# Now rebuild to make sure it's the latest
$premake --file=$premakeDir/premake4.lua embed --quiet --reporoot=$premakeDir "${args[@]}"
result=$?
if [[ $result == 0 ]]; then
	$premake --file=$premakeDir/premake4.lua --reporoot=$premakeDir --objdir=bin/$OS_VERSION/%{cfg.shortname} ninja "${args[@]}"
	result=$?
fi

if [[ $result != 0 ]]; then
	echo "Error : Failed to build Premake"
	rm $hashFile 2> /dev/null
fi

if [[ $verbose ]]; then
	echo "Built Premake & Ninja binaries."
	echo "---------------------"
fi

rm -f $TMP_DIR/buildingPremake.lock
exit $result

