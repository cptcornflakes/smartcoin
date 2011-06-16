#!/bin/bash
#clear
#echo "Starting..."

. $HOME/smartcoin/smartcoin_ops.sh


ShowStatus() {
	status=""
	UseDB "smartcoin"
	Q="Select device from card ORDER BY device ASC";
	R=$(RunSQL "$Q")


	for card in $R                                              
	do 
		cardID=$(Field 1 "$card")
	        temperature=` DISPLAY=:0 aticonfig --adapter=$cardID --odgt | awk '/Temperature/ { print $5 }';`
		usage=`DISPLAY=:0 aticonfig --adapter=$cardID --odgc | awk '/GPU\ load/ { print $4 }';`
		status=$status"GPU $cardID: Temp: $temperature load: $usage\n"
	done
	cpu=`iostat | awk '{if(NR==4) {print "CPU Load : " $1 "%"}}'`
	status=$status"$cpu\n"

	# Next lines are to check your balance if solo mining
        BALANCE=$(/home/jondecker76/bitcoin-0.3.21/bin/32/bitcoind getbalance)
        status=$status"Local Bitcoin balance : $BALANCE\n\n"
        



	#MT GOX
	#mtgox_balance=`wget -q --no-check-certificate --no-proxy -O - "https://www.mtgox.com/code/getFunds.php" --post-data="name=jondecker76&pass=ohio98yo"`
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



#card-miner-worker
UseDB "smartcoin"
Q="SELECT map.pk_map,map.fk_card, map.fk_miner, map.fk_worker,worker.fk_pool,card.name from map LEFT JOIN worker on map.fk_worker = worker.pk_worker LEFT JOIN card on map.fk_card = card.pk_card WHERE map.fk_profile=$CURRENT_PROFILE ORDER BY fk_pool,fk_card ASC;"
R=$(RunSQL "$Q")

	oldPool=""
	hashes="0.00"
	totalHashes="0.00"
	compositeHashes="0.00"
	for Row in $R; do
		PK=$(Field 1 "$Row")
		card=$(Field 2 "$Row")
		miner=$(Field 3 "$Row")
		worker=$(Field 4 "$Row")
		pool=$(Field 5 "$Row")
		cardName=$(Field 6 "$Row")

		
		if [ "$oldPool" != "$pool" ]; then

			if [ "$oldPool" != "" ]; then
			status=$status"Total: $totalHashes MHash/sec\n"
			compositeHashes=$(echo "scale=2; $compositeHashes+$totalHashes" | bc -l) 
			totalHashes="0.00"
			fi

			oldPool=$pool
			# get the name of the pool
			Q="SELECT name from pool where pk_pool=$pool;"
			R2=$(RunSQL "$Q")
			poolName=$(Field 1 "$R2")
			status=$status"--------$poolName--------\n"
		fi

		screen -p smartcoin.$PK -X hardcopy "$HOME/smartcoin/.smartcoin.$PK"
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
		rejected=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f3`
		if [ -z "$rejected" ]; then
			rejected="0"
		fi


	done
status=$status"Total: [$totalHashes MHash/sec]\n\n"
compositeHashes=$(echo "scale=2; $compositeHashes+$totalHashes" | bc -l) 
status=$status"Grand Total:\t[$compositeHashes Mhash/sec] [$compositeAccepted Accepted] [$compositeRejected Rejected] [$compositeStales% Stales]"

echo  $status
screen -p status -X hardcopy "$HOME/smartcoin/.smartcoin.status"



#for pool in $R                                                          
#do                         
	#echo ""
#	poolID=$(Field 1 "$pool")
#	poolName=$(Field 2 "$pool")

#	totalHashes="0.00" 
#	totalAccepted="0"
#	totalRejected="0"
        
#	Q="SELECT pk_card, device FROM card"
#	R2=$(RunSQL "$Q")    
                                        
 #       for card in $R2                                                  
  #      do   
#		cardID=$(Field 1 "$card")
#		cardName=$(Field 2 "$card")

                                                                   
#        	screen -p $card-$pool -X hardcopy .smart.$card-$pool
#		cmd=`cat  .smart.$card-$pool | grep Mhash`
#		if [ -z "$cmd" ]; then
#			cmd="<<<DOWN>>>"
#		fi
#		status=$status"$pool-$card:\t$cmd\n"                    
 #               hashes=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f1`
#		if [ -z "$hashes" ]; then
#			hashes="0.00"
#		fi
#		accepted=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f2`
#		if [ -z "$accepted" ]; then
#			accepted="0"
#		fi
#		rejected=`echo $cmd | sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g' | cut -d' ' -f3`
#		if [ -z "$rejected" ]; then
#			rejected="0"
#		fi
#
#	totalHashes=$(echo "scale=2; $totalHashes+$hashes" | bc -l)                          
#	totalAccepted=$(echo "scale=2; $totalAccepted+$accepted" | bc -l) 
#	totalRejected=$(echo "scale=2; $totalRejected+$rejected" | bc -l) 
 #       done    
#	status=$status"$pool-T:\t[$totalHashes Mhash/sec] [$totalAccepted Accepted] [$totalRejected Rejected]\n\n"                                                          
#compositeHashes=$(echo "scale=2; $compositeHashes+$totalHashes" | bc -l) 
#compositeAccepted=$(echo "scale=2; $compositeAccepted+$totalAccepted" | bc -l)
#compositeRejected=$(echo "scale=2; $compositeRejected+$totalRejected" | bc -l)
#done  
#compositeStales=$(echo "scale=2; $compositeRejected*100/$CompositeAccepted*100" | bc -l)                    
#status=$status"Grand Total:\t[$compositeHashes Mhash/sec] [$compositeAccepted Accepted] [$compositeRejected Rejected] [$compositeStales% Stales]"
#echo -e $status
#screen -p status -X hardcopy .smart.status
}


clear
echo "INITIALIZING SMARTCOIN....."
sleep 10

clear
while true; do
	UseDB "smartcoin"
	Q="SELECT value from settings where data=\"current_profile\";"
	R=$(RunSQL "$Q")
	CURRENT_PROFILE=$(Field 1 "$R")
	UI=$(ShowStatus)
	clear
	ShowHeader
	echo -e $UI
	sleep $statusRefresh
done

