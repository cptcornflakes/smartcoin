#!/bin/bash

# local location=`sudo find / -type d -regextype posix-extended -iregex '.*/(AMD|ATI)-(APP|STREAM)-SDK-v[[:digit:].]+-lnx(32|64)/lib/x86(_64)?$'`
# Look for 64 bit version first
location64=`sudo find / -type d -regextype posix-extended -iregex '.*/(AMD|ATI)-(APP|STREAM)-SDK-v[[:digit:].]+-lnx64/lib/x86_64?$'`
if [[ "$location64" != "" ]]; then
	echo "$location64"
	exit
fi

# Look for 32 bit version
location32=`sudo find / -type d -regextype posix-extended -iregex '.*/(AMD|ATI)-(APP|STREAM)-SDK-v[[:digit:].]+-lnx32/lib/x86?$'`
echo "$location32"
