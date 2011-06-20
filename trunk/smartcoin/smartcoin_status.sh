#!/bin/bash
#clear
#echo "Starting..."

. $HOME/smartcoin/smartcoin_ops.sh


ShowStatus() {
	status=""
	UseDB "smartcoin"
	Q="Select device from card WHERE disabled=0 ORDER BY device ASC";
	R=$(RunSQL "$Q")


	for card in $R                                              
	do 
		cardID=$(Field 1 "$card")
		sleep 0.2 # aticonfig seems to get upset sometimes if it is called very quickly in succession
	        temperature=`aticonfig --adapter=$cardID --odgt | awk '/Temperature/ { print $5 }';`
		sleep 0.2 # aticonfig seems to get upset sometimes if it is called very quickly in succession
		usage=`aticonfig --adapter=$cardID --odgc | awk '/GPU\ load/ { print $4 }';`
		status=$status"GPU $cardID: Temp: $temperature load: $usage\n"
	done
	cpu=`iostat | awk '{if(NR==4) {print "CPU Load : " $1 "%"}}'`
	status=$status"$cpu\n"

	# Next lines are to check your balance if solo mining
        BALANCE=`$HOME/bitcoin-0.3.212bin/32/bitcoind getbalance 2> /dev/null`
        status=$status"Local Bitcoin balance : $BALANCE\n\n"
        



	#MT GOX
	#mtgox_balance=`wget -q --no-check-certificate --no-proxy -O - "https://www.mtgox.com/code/getFunds.php" --post-data user=username&pass=password"`
	#mtgox_balance=${mtgox_balance//\"/}
	#mtgox_balance=${mtgox_balance//\{/}
	#mtgox_balance=${mtgox_balance//\}/}
	#mtgox_balance=${mtgox_balance//,/, }


	#mtgox_ticker=`curl -k -s https://mtgox.com/code/data/ticker.php`
	#mtgox_ticker=${mtgox_ticker//\"/}
	#mtgox_ticker=${mtgox_ticker//ticker:/}
	#mtgox_ticker=${mtgox_ticker//\{/}
	#mtgox_ticker=${mtgox_ticker//\}/}
	#mtgox_ticker=${mtgox_ticker//,/, }
	#echo "MTGOX Balance : ${mtgox_balance}"
	#echo "MTGOX Ticker : ${mtgox_ticker}"

	#DEEPBIT
	#db_stats=`curl -s http://deepbit.net/api/4dc87e1b81619710d4000003_AAFEC38D9B`

	#echo ""
	#echo "DeepBit : ${db_stats}"

	#SMARTMINER MONITOR

	compositeAccepted="0"
	compositeRejected="0"

	UseDB "smartcoin"
	Q="SELECT name FROM profile WHERE pk_profile=$CURRENT_PROFILE;"
	R=$(RunSQL "$Q")
	profileName=$(Field 1 "$R")
	status=$status"Profile: $profileName\n"

	UseDB "smartcoin"
	Q="SELECT map.pk_map,map.fk_card, map.fk_miner, map.fk_worker,worker.fk_pool,card.name from map LEFT JOIN worker on map.fk_worker = worker.pk_worker LEFT JOIN card on map.fk_card = card.pk_card WHERE map.fk_profile=$CURRENT_PROFILE ORDER BY fk_pool,fk_card ASC;"
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
		card=$(Field 2 "$Row")
		miner=$(Field 3 "$Row")
		worker=$(Field 4 "$Row")
		pool=$(Field 5 "$Row")
		cardName=$(Field 6 "$Row")

		
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
		status=$status"$cardName:\t$cmd\n"                    
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
	status=$status"Grand Total: [$compositeHashes Mhash/sec] [$compositeAccepted Accepted] [$compositeRejected Rejected] [$percentRejected% Rejection]"

	echo  $status
	screen -d -r $sessionName -p status -X hardcopy "$HOME/smartcoin/.smartcoin.status"





}

clear
echo "INITIALIZING SMARTCOIN....."

clear
while true; do
	UseDB "smartcoin"
	Q="SELECT value from settings where data=\"current_profile\";"
	R=$(RunSQL "$Q")
	CURRENT_PROFILE=$(Field 1 "$R")
	UI=$(ShowStatus)
	clear
	ShowHeader
	echo -ne $UI
	sleep $statusRefresh
done

