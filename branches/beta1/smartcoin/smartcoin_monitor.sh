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
Monitor_phoenix()
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

Monitor_poclbm()
{
	# For now, get hash counting working! Look into accepted/rejected later!
	cmd=`grep "khash/s" "/tmp/smartcoin-$key" | tail -n 1`
	
	if [ "$cmd" ]; then
		hashes=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f1`
		accepted="0"
		rejected="0"
	fi

	# Convert from khash to MHash
	hashes=`echo "scale=2; $hashes/1000" | bc -l 2> /dev/null`

	output="[$hashes MHash/sec] [$accepted Accepted] [$rejected Rejected]"
	if [[ "$hashes" == "0" ]]; then
		# Is it safe to say the profile is down?
		output="\e[00;31m<<<DOWN>>>\e[00m"
		let profileFailed++
	fi
}

Monitor_cgminer()
{
	cmd=`grep "(5s)" "/tmp/smartcoin-$key" | tail -n 1`

	if [[ "$cmd" == *Gh/s* ]]; then
		hashUnits="Ghash"
	elif [[ "$cmd" == *Mh/s* ]]; then
		hashUnits="Mhash"
	elif [[ "$cmd" == *kh/s* ]]; then
		hashUnits="khash"
	fi  

	if [ "$cmd" ]; then
		hashes=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f2`
		accepted=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f4`
		rejected=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f5`
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

	output="[$hashes MHash/sec] [$accepted Accepted] [$rejected Rejected]"
	if [[ "$hashes" == "0" ]]; then
		# Is it safe to say the profile is down?
		output="\e[00;31m<<<DOWN>>>\e[00m"
		let profileFailed++
	fi
}
