#!/bin/bash
#SMART (Simple Miner Administration for Remote Terminals)
if [[ $( dirname "$0" ) == "/usr/bin" ]]; then
	CUR_LOCATION=$(dirname $(readlink -f $( dirname "$0" )/smartcoin))
else
	CUR_LOCATION="$( cd "$( dirname "$0" )" && pwd )"
fi
. $CUR_LOCATION/smartcoin_ops.sh

# Start the backend service
#$HOME/smartcoin/smartcoin_backend.sh &




echo "Starting SmartCoin at location: $CUR_LOCATION..."

running=`screen -ls 2> /dev/null | grep $sessionName`

echo "Running check"

if [[ "$running" ]]; then
	attached=`screen -ls | grep -i attached`
	echo "Re-attaching to smartcoin..."
	if [[ "$attached" != "" ]]; then
		screen -x $sessionName -p status
	else
		screen -r $sessionName -p status
	fi
	
	exit
fi

Log "******************* NEW SMARTCOIN SESSION STARTED *******************" 
Log "Starting main smartcoin screen session..." 1

# Let the user have their own custom initialization script if they want
if [[ -f "$CUR_LOCATION/init.sh" ]]; then
	Log "User initialization script found. Running initialization script." 1
	$CUR_LOCATION/init.sh
fi

DeleteTemporaryFiles
RotateLogs

screen -d -m -S $sessionName -t control "$CUR_LOCATION/smartcoin_control.sh"
screen -r $sessionName -X zombie ko
screen -r $sessionName -X chdir
screen -r $sessionName -X hardstatus on
screen -r $sessionName -X hardstatus alwayslastline
screen -r $sessionName -X hardstatus string '%{= kG}[ %{G}%H %{g}][%= %{= kw}%?%-Lw%?%{r}(%{W}%n*%f%t%?(%u
)%?%{r})%{w}%?%+Lw%?%?%= %{g}][%{B} %m/%d/%y %{W}%c %{g}]'

Log "Creating tab for each machine..." 1
# Create a new window for each machine
Q="SELECT pk_machine, name FROM machine;"
R=$(RunSQL "$Q")
for row in $R; do
	pk_machine=$(Field 1 "$row")
	machineName=$(Field 2 "$row")
	Log "	$machineName"
	screen -r $sessionName -X screen -t $machineName "$CUR_LOCATION/smartcoin_status.sh" "$pk_machine"
done


clear
GotoStatus




