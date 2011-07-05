#!/bin/bash
if [[ $( dirname "$0" ) == "/usr/bin" ]]; then
	CUR_LOCATION=$(pwd)
else
	CUR_LOCATION="$( cd "$( dirname "$0" )" && pwd )"
fi
. $CUR_LOCATION/smartcoin_ops.sh

# Reserved for future use
