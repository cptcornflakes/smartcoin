#!/bin/bash

# smartcoin_status.sh
# The name is a bit misleading, as this script does more than report status information.
# This script is also responsible for launching/killing processes as well as handling
# profile information.
# One instance of smartcoin_status runs on the local host, for each machine being controlled.




. $HOME/smartcoin/smartcoin_ops.sh

MACHINE=$1
Log "Starting status monitor for machine $MACHINE"

Q="SELECT COUNT(*) FROM worker;"
R=$(RunSQL "$Q")
oldWorkers=$(Field 1 "$R")


WorkersChanged() {
	Q="SELECT COUNT(*) FROM worker;"
	R=$(RunSQL "$Q")
	curWorkers=$(Field 1 "$R")

	if [[ "$curWorkers" != "$oldWorkers" ]]; then
		oldWorkers=$curWorkers
		echo "true"
	else
		echo ""
	fi

}

# Automaticall load a profile whenever it changes
oldProfile=""


LoadProfileOnChange()
{
	# Watch for a change in the profile
	newProfile=$(GetCurrentProfile $MACHINE)
	
	if [[ $(GetCurrentProfile) == -1 ]]; then
		if [[  $(WorkersChanged) ]]; then
			Log "NEW WORKERS DETECTED!"
			DeleteTemporaryFiles
			killMiners
			clear
			ShowHeader
			echo "New workers have been added.  Regenerating the automatic profile...."
			startMiners $MACHINE	
		fi
	fi
	if [[ "$newProfile" != "$oldProfile" ]]; then
		Log "NEW PROFILE DETECTED!"
		Log "	Switching from profile: $oldProfile to profile: $newProfile"
		DeleteTemporaryFiles
		oldProfile=$newProfile
		# Reload the miner screen session
		killMiners
		clear
		ShowHeader
		echo "A configuration change has been detected.  Loading the new profile...."
		startMiners $MACHINE	
	fi		
}




ShowStatus() {
	status=""

	Q="SELECT name FROM machine WHERE pk_machine=$MACHINE"
	R=$(RunSQL "$Q")
	hostName=$(Field 1 "$R")

	status="\e[01;33mHost: $hostName\e[00m\n"
	UseDB "smartcoin"
	Q="Select name,device,type from device WHERE fk_machine=$MACHINE AND disabled=0 ORDER BY device ASC";
	R=$(RunSQL "$Q")


	for device in $R                                              
	do 
		deviceName=$(Field 1 "$device")
		deviceID=$(Field 2 "$device")
		deviceType=$(Field 3 "$device")
		if [[ "$deviceType" == "gpu" ]]; then
			sleep 0.2 # aticonfig seems to get upset sometimes if it is called very quickly in succession
		        temperature=`aticonfig --adapter=$deviceID --odgt | awk '/Temperature/ { print $5 }';`
			sleep 0.2 # aticonfig seems to get upset sometimes if it is called very quickly in succession
			usage=`aticonfig --adapter=$deviceID --odgc | awk '/GPU\ load/ { print $4 }';`
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

	oldPool=""
	hashes="0.00"
	totalHashes="0.00"
	compositeHashes="0.00"
	accepted="0"
	totalAccepted="0"
	compositeAccepted="0"
	rejected="0"
	totalRejected="0"
	compositeRejected="0"

	for Row in $FA; do
		key=$(Field 1 "$Row")
		device=$(Field 2 "$Row")
		miner=$(Field 3 "$Row")
		worker=$(Field 4 "$Row")

		FAworker=$(GetWorkerInfo "$worker")
		pool=$(Field 5 "$FAworker")

		Q="SELECT name FROM device WHERE pk_device=$device;"
		deviceName=$(RunSQL "$Q")

		
		if [ "$oldPool" != "$pool" ]; then

			if [ "$oldPool" != "" ]; then
			status=$status"Total : [$totalHashes MHash/sec] [$totalAccepted Accepted] [$totalRejected Rejected]\n"
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

		screen -d -r $minerSession -p $key -X hardcopy "$HOME/smartcoin/.$key"
		cmd=`cat  "$HOME/smartcoin/.$key" | grep Mhash`
		if [ -z "$cmd" ]; then
			cmd="\e[00;31m<<<DOWN>>>\e[00m"
		fi
		status=$status"$deviceName:\t$cmd\n"                    
                hashes=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f1`
		if [ -z "$hashes" ]; then
			hashes="0.00"
		fi
		totalHashes=$(echo "scale=2; $totalHashes+$hashes" | bc -l)

		accepted=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f2`
		if [ -z "$accepted" ]; then
			accepted="0"
		fi
		totalAccepted=`expr $totalAccepted + $accepted`
		rejected=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f3`
		if [ -z "$rejected" ]; then
			rejected="0"
		fi
		totalRejected=`expr $totalRejected + $rejected`


	done
	status=$status"Total : [$totalHashes MHash/sec] [$totalAccepted Accepted] [$totalRejected Rejected]\n\n"
	compositeHashes=$(echo "scale=2; $compositeHashes+$totalHashes" | bc -l) 
	compositeAccepted=`expr $compositeAccepted + $totalAccepted`
	compositeRejected=`expr $compositeRejected + $totalRejected`
	percentRejected=$(echo "scale=2; $compositeRejected / $compositeAccepted* 100" | bc -l)
	if [ -z "$percentRejected" ]; then
		percentRejected="0"
	fi
	status=$status"Grand Total: [$compositeHashes Mhash/sec] [$compositeAccepted Accepted] [$compositeRejected Rejected] [$percentRejected% Rejected]"

	echo  $status
	screen -d -r $sessionName -p status -X hardcopy "$HOME/smartcoin/.smartcoin.status"





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

