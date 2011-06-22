#!/bin/bash
#clear
#echo "Starting..."

. $HOME/smartcoin/smartcoin_ops.sh

machine=$1
device=$2
miner=$3
worker=$4


UseDB "smartcoin"

# Get additional information on the device
Q="SELECT name,device from device WHERE pk_device=$device;"
R2=$(RunSQL "$Q")
thisDevice=$(Field 2 "$R2")
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
minerLaunch=${minerLaunch//<#device#>/$thisDevice}

pushd $minerPath
cd $minerPath && ./$minerLaunch
popd
