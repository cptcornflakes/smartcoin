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
. $CUR_LOCATION/smartcoin_monitor.sh


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
lastProfile=""
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
			return
		fi
		
	fi
	if [[ "$newProfile" != "$lastProfile" ]]; then
		Log "NEW PROFILE DETECTED!"
		Log "	Switching from profile: $lastProfile to profile: $newProfile"
		DeleteTemporaryFiles
		lastProfile=$newProfile
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
		if [[ "$db_count" -ge "8" ]]; then
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
	xml_out="<?xml version=\"1.0\"?>\n"
	xml_out=$xml_out"<smartcoin>\n"

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
	profileFailed=0
	hardlocked=0

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

	
		# TODO: Optimize the following queries by including in the GenCurrentProfile call?
		Q="SELECT name FROM device WHERE pk_device=$device;"
		deviceName=$(RunSQL "$Q")
		Q="SELECT launch FROM miner WHERE pk_miner='$miner';"
		minerLaunch=$(RunSQL "$Q")		

		failOverStatus=""
		if [[ "$profileName" == "Failover" ]]; then
			if [[ "$oldProfile" != "$thisProfile" ]]; then
				if [[ "$oldProfile" != "" ]]; then
					MarkFailedProfiles $oldProfile $profileFailed
					profileFailed=0
					Q="SELECT name FROM profile WHERE pk_profile='$thisProfile';"
					R=$(RunSQL "$Q")
					nextProfileName=$(Field 1 "$R")

				

				fi
				oldProfile=$thisProfile
				failOverStatus="\n\e[01;33mFailover to: $nextProfileName\e[00m\n"
			fi
		fi


		if [ "$oldPool" != "$pool" ]; then

			if [ "$oldPool" != "" ]; then
				status=$status"Total : [$totalHashes MHash/sec] [$totalAccepted Accepted] [$totalRejected Rejected] [$percentRejected%  Rejected]\n"
				status="$status$failOverStatus"

				compositeHashes=$(echo "scale=2; $compositeHashes+$totalHashes" | bc -l) 
				compositeAccepted=`expr $compositeAccepted + $totalAccepted`
				compositeRejected=`expr $compositeRejected + $totalRejected`
			
				
				xml_out=$xml_out"\t<worker>\n"	
				xml_out=$xml_out"\t\t<name>$oldPool</name>\n"
				xml_out=$xml_out"\t\t<hashes>$totalHashes</hashes>\n"
				xml_out=$xml_out"\t\t<accepted>$totalAccepted</accepted>\n"
				xml_out=$xml_out"\t\t<rejected>$totalRejected</rejected>\n"
				xml_out=$xml_out"\t\t<rejected_percent>$percentRejected</rejected_percent>\n"
				xml_out=$xml_out"\t</worker>\n"
		


				totalHashes="0.00"
				totalAccepted="0"
				totalRejected="0"
			fi

			oldPool=$pool
			status=$status"\e[01;32m--------$pool--------\e[00m\n"
		fi

		# TODO: Look for hardlock conditions!
		oldMinerOutput=`cat "/tmp/smartcoin-$key" 2> /dev/null`
		screen -d -r $minerSession -p $key -X hardcopy "/tmp/smartcoin-$key"
		newMinerOutput=`cat "/tmp/smartcoin-$key" 2> /dev/null`

		if [[ "$oldMinerOutput" == "$newMinerOutput" ]]; then
			# Increment counter
			local cnt=$(cat /tmp/smartcoin-$key.lockup 2> /dev/null)
			if [[ -z "$cnt" ]]; then
				cnt="0"
			fi
		
			if [[ "$cnt" -lt "10" ]]; then
				let cnt++
				echo "$cnt" > /tmp/smartcoin-$key.lockup
			fi

			if [[ "$cnt" -eq "10" ]]; then
				let cnt++
				echo "$cnt" > /tmp/smartcoin-$key.lockup
				Log "ERROR: It appears that one or more of your devices have locked up.  This is most likely the result of extreme overclocking!"
				Log "       It is recommended that you reduce your overclocking until you regain stability of the system"
				# Kill the miners
				killMiners
				# Commit suicide
				screen -d -r $sessionName -X quit

				# Send email

			fi


		else
			# Reset counter
			rm /tmp/smartcoin-$key.lockup 2> /dev/null
		fi


		hashes="0"
		accepted="0"
		rejected="0"
		output=""

		case "$minerLaunch" in
		*phoenix.py*)
			Monitor_phoenix
			;;
		*poclbm.py*)
			Monitor_poclbm
			;;
		*cgminer*)
			Monitor_cgminer
			;;
		esac

		status=$status"$deviceName:\t$output\n"                    
                
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
		percentRejected=`echo "scale=3;a=($totalRejected*100) ; b=$totalAccepted; c=a/b; print c" | bc -l 2> /dev/null`
		if [ -z "$percentRejected" ]; then
			percentRejected="0.00"
		fi
		
		# Fail profile on unusually high rejection percentage
		# TODO: Get rid of hard-coded limit, and make as a new setting
		if [[ "$percentRejected" -gt "10" ]]; then
			let profileFailed++
		fi
	done

	MarkFailedProfiles $oldProfile $profileFailed

	status=$status"Total : [$totalHashes MHash/sec] [$totalAccepted Accepted] [$totalRejected Rejected] [$percentRejected%  Rejected]\n\n"
	compositeHashes=$(echo "scale=2; $compositeHashes+$totalHashes" | bc -l) 
	compositeAccepted=`expr $compositeAccepted + $totalAccepted`
	compositeRejected=`expr $compositeRejected + $totalRejected`

	xml_out=$xml_out"\t<worker>\n"	
	
	xml_out=$xml_out"\t\t<name>$oldPool</name>\n"
	xml_out=$xml_out"\t\t<hashes>$totalHashes</hashes>\n"
	xml_out=$xml_out"\t\t<accepted>$totalAccepted</accepted>\n"
	xml_out=$xml_out"\t\t<rejected>$totalRejected</rejected>\n"
	xml_out=$xml_out"\t\t<rejected_percent>$percentRejected</rejected_percent>\n"
	xml_out=$xml_out"\t</worker>\n"


	percentRejected=`echo "scale=3;a=($compositeRejected*100) ; b=$compositeAccepted; c=a/b; print c" | bc -l 2> /dev/null`
	
	if [ -z "$percentRejected" ]; then
		percentRejected="0.00"
	fi
	status=$status"Grand Total: [$compositeHashes MHash/sec] [$compositeAccepted Accepted] [$compositeRejected Rejected] [$percentRejected%  Rejected]"

	echo  $status
	#screen -d -r $sessionName -p status -X hardcopy "/tmp/smartcoin-status"

	
	xml_out=$xml_out"\t<grand_total>\n"
	xml_out=$xml_out"\t\t<hashes>$compositeHashes</hashes>\n"
	xml_out=$xml_out"\t\t<accepted>$compositeAccepted</accepted>\n"
	xml_out=$xml_out"\t\t<rejected>$compositeRejected</rejected>\n"
	xml_out=$xml_out"\t\t<rejected_percent>$percentRejected</rejected_percent>\n"
	xml_out=$xml_out"\t</grand_total>\n"
	xml_out=$xml_out"</smartcoin>"
	echo -e "$xml_out" > /tmp/smartcoin.xml
	


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

