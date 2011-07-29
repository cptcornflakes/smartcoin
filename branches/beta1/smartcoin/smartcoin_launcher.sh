#!/bin/bash
#clear
#echo "Starting..."

if [[ $( dirname "$0" ) == "/usr/bin" ]]; then
	CUR_LOCATION=$(dirname $(readlink -f $( dirname "$0" )/smartcoin))
else
	CUR_LOCATION="$( cd "$( dirname "$0" )" && pwd )"
fi
. $CUR_LOCATION/smartcoin_ops.sh

machine=$1
device=$2
miner=$3
worker=$4




UseDB "smartcoin.db"

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
minerLaunch=${minerLaunch//<#path#>/$minerPath}

echo "LAUNCH: $minerLaunch"
Log "Launching miner with launch string: $minerLaunch" 1

case "$minerLaunch" in
*phoenix.py*)
	# Phoenix requires its path be in $LD_LIBRARY_PATH to launch from script
	if [[ "$LD_LIBRARY_PATH" == *$minerPath* ]]; then
		# It has not yet been added. Add the phoenixPath to LD_LIBRARY_PATH
		export LD_LIBRARY_PATH=$minerPath:$LD_LIBRARY_PATH
	fi
	;;
esac


$minerLaunch 2>/dev/null

