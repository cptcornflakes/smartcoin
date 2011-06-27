#!/bin/bash
#clear
#echo "Starting..."

. $HOME/smartcoin/smartcoin_ops.sh

machine=$1
device=$2
miner=$3
worker=$4

# Lets fix up our $LD_LIBRARY_PATH
Q="SELECT value FROM settings WHERE data='AMD_SDK_location';"
R=$(RunSQL "$Q")
amd_sdk_location=$(Field 1 "$R")

Q="SELECT value FROM settings WHERE data='phoenix_location';"
R=$(RunSQL "$Q")
phoenix_location=$(Field 1 "$R")

if [[ "$amd_sdk_location" ]]; then
	echo "Exporting the AMD/ATI SDK path to LD_LIBRARY_PATH: $amd_sdk_location"
	export LD_LIBRARY_PATH=$amd_sdk_location:$LD_LIBRARY_PATH
fi
if [[ "$phoenix_location" ]]; then
	echo "Exporting the phoenix path to LD_LIBRARY_PATH: $phoenix_location"
	export LD_LIBRARY_PATH=$phoenix_location:$LD_LIBRARY_PATH
fi	


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

R2=$(GetWorkerInfo "$worker")
echo $R2


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

echo "LAUNCH: $minerLaunch"

#pushd $minerPath
cd $minerPath && ./$minerLaunch
#popd
