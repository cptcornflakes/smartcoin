#!/bin/bash
if [[ $( dirname "$0" ) == "/usr/bin" ]]; then
	CUR_LOCATION=$(dirname $(readlink -f $( dirname "$0" )/smartcoin))
else
	CUR_LOCATION="$( cd "$( dirname "$0" )" && pwd )"
fi
. $CUR_LOCATION/smartcoin_ops.sh


# Monitoring functions perform the following:
# 1) Load in /tmp/smartcoin-$key via grep looking for specific strings
# 2) work with $hashes, $rejected and $accepted global variables
# 3) Create an $output variable with the line to output
# 4) Hashing  units are handled internally as MHash.  Conversion must be done on the fly for other bases


# PHOENIX monitoring
MonitorPhoenix()
{
	cmd=`grep "hash" "/tmp/smartcoin-$key" | tail -n 1`
	starting=`grep "starting" "/tmp/smartcoin-$key" | tail -n 1`


	if [[ "$cmd" == *Ghash* ]]; then
		hashUnits="Ghash"
	elif [[ "$cmd" == *Mhash* ]]; then
		hashUnits="Mhash"
	elif [[ "$cmd" == *khash* ]]; then
		hashUnits="khash"

	fi  

	


	if [ "$cmd" ]; then
		hashes=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f1`
		accepted=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f2`
		rejected=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f3`
	fi

	# Convert into MHash if needed
	case $hashUnits in
	Ghash)
		hashes=`echo "scale=2; $hashes*1000" | bc -l 2> /dev/null`
		;;
	Mhash)
		# We are already scaled to MHash, do nothing!
		hashes=$hashes
		;;
	khash)
		hashes=`echo "scale=2; $hashes/1000" | bc -l 2> /dev/null`
		;;
	esac

	output="$cmd"
	if [[ -z "$cmd" ]]; then
		if [[ "$starting" ]]; then
			output="\e[00;31m<<<STARTING>>>\e[00m"	
		else
			output="\e[00;31m<<<IDLE>>>\e[00m"	
			# TODO: increment failure counter here??
		fi
	else
		if [[ "$hashes" == "0" ]]; then
			# Is it safe to say the profile is down?
			output="\e[00;31m<<<DOWN>>>\e[00m"
			let profileFailed++

		fi
	fi

}
