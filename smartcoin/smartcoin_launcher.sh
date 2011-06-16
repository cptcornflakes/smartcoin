#!/bin/bash
#clear
#echo "Starting..."

. $HOME/smartcoin/smartcoin_ops.sh


card=$1
miner=$2
worker=$3


UseDB "smartcoin"

# Get additional information on the card
Q="SELECT name,device from card WHERE pk_card=$card;"
R2=$(RunSQL "$Q")
device=$(Field 2 "$R2")
# Get the miner information
Q="SELECT name, path,launch FROM miner WHERE pk_miner=$miner;"
R2=$(RunSQL "$Q")
minerName=$(Field 1 "$R2")
minerPath=$(Field 2 "$R2")
minerLaunch=$(Field 3 "$R2")
# Get the worker and pool information
Q="SELECT user,pass,pool.server, pool.port from worker LEFT JOIN pool ON worker.fk_pool = pool.pk_pool WHERE pk_worker=$worker;"
R2=$(RunSQL "$Q")
workerServer=$(Field 3 "$R2")
workerPort=$(Field 4 "$R2")
workerUser=$(Field 1 "$R2")
workerPass=$(Field 2 "$R2")

#Make launch string
minerLaunch=${minerLaunch//<#user#>/$workerUser}
minerLaunch=${minerLaunch//<#pass#>/$workerPass}
minerLaunch=${minerLaunch//<#server#>/$workerServer}
minerLaunch=${minerLaunch//<#port#>/$workerPort}
minerLaunch=${minerLaunch//<#device#>/$device}

pushd $minerPath
cd $minerPath && ./$minerLaunch
popd
