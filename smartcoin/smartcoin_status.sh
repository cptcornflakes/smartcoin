#!/bin/bash

# smartcoin_status.sh
# The name is a bit misleading, as this script does more than report status information.
# This script is also responsible for launching/killing processes as well as handling
# profile information.
# One instance of smartcoin_status runs on the local host, for each machine being controlled.




if [[ $( dirname "$0" ) == "/usr/bin" ]]; then
	CUR_LOCATION=$(dirname $(readlink -f $( dirname "$0" )/smartcoin))
else
	CUR_LOCATION="$( cd "$( dirname "$0" )" && pwd )"
fi
. $CUR_LOCATION/smartcoin_ops.sh


MACHINE=$1
Log "Starting status monitor for machine $MACHINE"

oldWorkers=""
Q="SELECT COUNT(*) FROM worker;"
R=$(RunSQL "$Q")
oldWorkers=$(Field 1 "$R")


WorkersChanged() {
	Q="SELECT COUNT(*) FROM worker;"
	R=$(RunSQL "$Q")
	newWorkers=$(Field 1 "$R")

	if [[ "$oldWorkers" != "$newWorkers" ]]; then
		
		echo "true"
	else
		echo ""
	fi

}

# Automaticall load a profile whenever it changes
oldProfile=""
oldFA=""

LoadProfileOnChange()
{
	# Watch for a change in the profile
	newProfile=$(GetCurrentProfile $MACHINE)
	newFA=$(GenCurrentProfile "$MACHINE")
	changed=$(WorkersChanged)

	if [[ "$newProfile" == "-1" ]]; then

		if [[  "$changed" ]]; then
			Q="SELECT COUNT(*) FROM worker;"
			R=$(RunSQL "$Q")
			newWorkers=$(Field 1 "$R")
			oldWorkers=$newWorkers
			Log "WORKER CHANGE DETECTED!"
			DeleteTemporaryFiles
			killMiners
			clear
			ShowHeader
			echo "The number of workers has changed.  Regenerating the automatic profile...."
			startMiners $MACHINE	
		fi
		return
	fi
	if [[ "$newProfile" != "$oldProfile" ]]; then
		Log "NEW PROFILE DETECTED!"
		Log "	Switching from profile: $oldProfile to profile: $newProfile"
		DeleteTemporaryFiles
		oldProfile=$newProfile
		oldFA=$newFA
		# Reload the miner screen session
		killMiners
		clear
		ShowHeader
		echo "A configuration change has been detected.  Loading the new profile...."
		startMiners $MACHINE	
		return
	fi
	# This should only happen if a failover event takes place	
	if [[ "$newFA" != "$oldFA"  ]]; then
		Log "A change was detected in the failover system"
		oldFA=$newFA
		killMiners
		clear
		ShowHeader
		echo "A configuration change has been detected. Reconfiguring Failover..."
		startMiners $MACHINE	
		return
	fi

		
}

MarkFailedProfiles()
{
	local theProfile=$1
	local failure=$2

	#Log "DEBUG: In MarkFailedProfiles()"
	if [[ "$profileName" == "Failover" ]]; then
		# We're in Failover mode.

		Q="SELECT down,failover_count FROM profile WHERE pk_profile='$theProfile';"
		R=$(RunSQL "$Q")
		local db_failed=$(Field 1 "$R")
		local db_count=$(Field 2 "$R")

		if [[ "$failure" -gt "0" ]]; then
			failure=1
		fi

		if [[ "$failure" != "$db_failed" ]]; then
			let db_count++
		else
			db_count=0
		fi
		#Log "DEBUG: failure=$failure"
		#Log "DEBUG: db_count=$db_count"
		#Log "DEBUG: db_failed=$db_failed"

		Q="UPDATE profile SET failover_count='$db_count' WHERE pk_profile='$theProfile';"
		RunSQL "$Q"
		#Log "DEBUG: $Q"

		# TODO: replace hard-coded max count with a setting?
		if [[ "$db_count" -ge "10" ]]; then
			let db_failed=db_failed^1
			Q="UPDATE profile SET down='$db_failed', failover_count='0' WHERE pk_profile='$theProfile';"
			RunSQL "$Q"
			#Log "DEBUG: $Q"
		fi
			
	fi
}


profileDownCount="0"
profileDown="0"

ShowStatus() {
	export DISPLAY=:0
	status=""

	Q="SELECT name FROM machine WHERE pk_machine=$MACHINE"
	R=$(RunSQL "$Q")
	hostName=$(Field 1 "$R")

	status="\e[01;33mHost: $hostName\e[00m\n"
	UseDB "smartcoin.db"
	Q="Select name,device,type from device WHERE fk_machine=$MACHINE AND disabled=0 ORDER BY device ASC";
	R=$(RunSQL "$Q")


	for device in $R                                              
	do 
		deviceName=$(Field 1 "$device")
		deviceID=$(Field 2 "$device")
		deviceType=$(Field 3 "$device")
		if [[ "$deviceType" == "gpu" ]]; then
			sleep 0.2 # aticonfig seems to get upset sometimes if it is called very quickly in succession
		        temperature=$(aticonfig --adapter=$deviceID --odgt | awk '/Temperature/ { print $5 }';)
			sleep 0.2 # aticonfig seems to get upset sometimes if it is called very quickly in succession
      usage=$(aticonfig --adapter=$deviceID --odgc | awk '/GPU\ load/ { print $4 }';)
			status=$status"$deviceName: Temp: $temperature load: $usage\n"
		fi
	done
	cpu=`iostat | awk '{if(NR==4) {print "CPU Load : " $1 "%"}}'`
	status=$status"$cpu\n\n"

	compositeAccepted="0"
	compositeRejected="0"

	# Get current profile for the machine number
	profileName=$(GetProfileName "$MACHINE")


	status=$status"\e[01;33mProfile: $profileName\e[00m\n"
	FA=$(GenCurrentProfile "$MACHINE")
	local profileFailed=0

	oldPool=""
	oldProfile=""
	profileFailed="0"
	hashes="0.00"
	totalHashes="0.00"
	compositeHashes="0.00"
	accepted="0"
	totalAccepted="0"
	compositeAccepted="0"
	rejected="0.00"
	totalRejected="0"
	compositeRejected="0"
	
	

	for Row in $FA; do
		thisProfile=$(Field 1 "$Row")
		key=$(Field 2 "$Row")
		device=$(Field 3 "$Row")
		miner=$(Field 4 "$Row")
		worker=$(Field 5 "$Row")

		FAworker=$(GetWorkerInfo "$worker")
		pool=$(Field 5 "$FAworker")

		Q="SELECT name FROM device WHERE pk_device=$device;"
		deviceName=$(RunSQL "$Q")

		

		if [[ "$oldProfile" != "$thisProfile" ]]; then
			if [[ "$oldProfile" != "" ]]; then
				MarkFailedProfiles $oldProfile $profileFailed
				profileFailed=0
			fi
			oldProfile=$thisProfile
		fi


		if [ "$oldPool" != "$pool" ]; then

			if [ "$oldPool" != "" ]; then
				status=$status"Total : [$totalHashes $hashUnits/sec] [$totalAccepted Accepted] [$totalRejected Rejected]\n"
				compositeHashes=$(echo "scale=2; $compositeHashes+$totalHashes" | bc -l) 
				compositeAccepted=`expr $compositeAccepted + $totalAccepted`
				compositeRejected=`expr $compositeRejected + $totalRejected`
			
				
				
				
		


				totalHashes="0.00"
				totalAccepted="0"
				totalRejected="0"
			fi

			oldPool=$pool
			status=$status"\e[01;32m--------$pool--------\e[00m\n"
		fi

		screen -d -r $minerSession -p $key -X hardcopy "/tmp/smartcoin-$key"
		#cmd=`tac  "/tmp/smartcoin-$key" | grep hash`
		cmd=`grep "hash" "/tmp/smartcoin-$key" | tail -n 1`
		#cmd=`tail -n 1 /tmp/smartcoin-$key | grep hash`
		if [[ "$cmd" == *GHash* ]]; then
			hashUnits="GHash"
		elif [[ "$cmd" == *Mhash* ]]; then
			hashUnits="Mhash"
		elif [[ "$cmd" == *khash* ]]; then
			hashUnits="khash"
		else
			hashUnits="hash"
		fi  
      
		if [ -z "$cmd" ]; then
			hashes="0"
			accepted="0"
			rejected="0"
		else
			hashes=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f1`
			accepted=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f2`
			rejected=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f3`
		fi


		if [[ "$hashes" == "0" ]]; then
			# Is it safe to say the profile is down?
			cmd="\e[00;31m<<<DOWN>>>\e[00m"
			let profileFailed++

		fi


		status=$status"$deviceName:\t$cmd\n"                    
                
		if [ -z "$hashes" ]; then
			hashes="0.00"
		fi
		if [ -z "$accepted" ]; then
			accepted="0"
		fi
		if [ -z "$rejected" ]; then
			rejected="0"
		fi

		totalHashes=$(echo "scale=2; $totalHashes+$hashes" | bc -l)
		totalAccepted=`expr $totalAccepted + $accepted`
		totalRejected=`expr $totalRejected + $rejected`
	done

	MarkFailedProfiles $oldProfile $profileFailed

	status=$status"Total : [$totalHashes MHash/sec] [$totalAccepted Accepted] [$totalRejected Rejected]\n\n"
	compositeHashes=$(echo "scale=2; $compositeHashes+$totalHashes" | bc -l) 
	compositeAccepted=`expr $compositeAccepted + $totalAccepted`
	compositeRejected=`expr $compositeRejected + $totalRejected`
	percentRejected=`echo "scale=3;a=($compositeRejected*100) ; b=$compositeAccepted; c=a/b; print c" | bc -l`
	
	if [ -z "$percentRejected" ]; then
		percentRejected="0.00"
	fi
	status=$status"Grand Total: [$compositeHashes $hashUnits/sec] [$compositeAccepted Accepted] [$compositeRejected Rejected] [$percentRejected%  Rejected]"

	echo  $status
	#screen -d -r $sessionName -p status -X hardcopy "/tmp/smartcoin-status"





}

clear
echo "INITIALIZING SMARTCOIN....."

clear
while true; do
	LoadProfileOnChange
	UI=$(ShowStatus)
	clear
	ShowHeader
	echo -ne $UI
	sleep $statusRefresh
done

