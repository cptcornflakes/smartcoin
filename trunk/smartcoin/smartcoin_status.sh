#!/bin/bash
#clear
#echo "Starting..."

. $HOME/smartcoin/smartcoin_ops.sh


ShowStatus() {
	status=""
	UseDB "smartcoin"
	Q="Select device,type from device WHERE disabled=0 ORDER BY device ASC";
	R=$(RunSQL "$Q")


	for device in $R                                              
	do 
		deviceID=$(Field 1 "$device")
		deviceType=$(Field 2 "$device")
		if [[ "$deviceType" == "gpu" ]]; then
			sleep 0.2 # aticonfig seems to get upset sometimes if it is called very quickly in succession
		        temperature=`aticonfig --adapter=$deviceID --odgt | awk '/Temperature/ { print $5 }';`
			sleep 0.2 # aticonfig seems to get upset sometimes if it is called very quickly in succession
			usage=`aticonfig --adapter=$deviceID --odgc | awk '/GPU\ load/ { print $4 }';`
			status=$status"GPU $deviceID: Temp: $temperature load: $usage\n"
		fi
	done
	cpu=`iostat | awk '{if(NR==4) {print "CPU Load : " $1 "%"}}'`
	status=$status"$cpu\n"

	compositeAccepted="0"
	compositeRejected="0"

	# Get current profile for the machine number
	# TODO: machine logic
	# TODO: make into a generalized function in smartcoin_ops.sh
	Q="SELECT fk_profile from current_profile WHERE fk_machine=1;"
	R=$(RunSQL "$Q")
	$CURRENT_PROFILE=$(Field 1 "$R")

	UseDB "smartcoin"
	Q="SELECT name FROM profile WHERE pk_profile=$CURRENT_PROFILE;"
	R=$(RunSQL "$Q")
	profileName=$(Field 1 "$R")
	status=$status"Profile: $profileName\n"

	UseDB "smartcoin"
	Q="SELECT profile_map.pk_profile_map,profile_map.fk_device, profile_map.fk_miner, profile_map.fk_worker,worker.fk_pool,device.name from profile_map LEFT JOIN worker on profile_map.fk_worker = worker.pk_worker LEFT JOIN device on profile_map.fk_device = device.pk_device WHERE profile_map.fk_profile=$CURRENT_PROFILE ORDER BY fk_pool,fk_device ASC;"
	R=$(RunSQL "$Q")

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

	for Row in $R; do
		PK=$(Field 1 "$Row")
		device=$(Field 2 "$Row")
		miner=$(Field 3 "$Row")
		worker=$(Field 4 "$Row")
		pool=$(Field 5 "$Row")
		deviceName=$(Field 6 "$Row")

		
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
			# get the name of the pool
			Q="SELECT name from pool where pk_pool=$pool;"
			R2=$(RunSQL "$Q")
			poolName=$(Field 1 "$R2")
			status=$status"--------$poolName--------\n"
		fi

		screen -d -r $minerSession -p smartcoin.$PK -X hardcopy "$HOME/smartcoin/.smartcoin.$PK"
		cmd=`cat  "$HOME/smartcoin/.smartcoin.$PK" | grep Mhash`
		if [ -z "$cmd" ]; then
			cmd="<<<DOWN>>>"
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
	percentRejected=$(echo "scale=2; $compositeRejected / $compositeAccepted" | bc -l)
	if [ -z "$percentRejected" ]; then
		percentRejected="0"
	fi
	status=$status"Grand Total: [$compositeHashes Mhash/sec] [$compositeAccepted Accepted] [$compositeRejected Rejected] [$percentRejected% Rejection]"

	echo  $status
	screen -d -r $sessionName -p status -X hardcopy "$HOME/smartcoin/.smartcoin.status"





}

clear
echo "INITIALIZING SMARTCOIN....."

clear
while true; do
	UseDB "smartcoin"
	Q="SELECT fk_profile FROM current_profile WHERE fk_machine=1;"
	R=$(RunSQL "$Q")
	CURRENT_PROFILE=$(Field 1 "$R")
	UI=$(ShowStatus)
	clear
	ShowHeader
	echo -ne $UI
	sleep $statusRefresh
done

