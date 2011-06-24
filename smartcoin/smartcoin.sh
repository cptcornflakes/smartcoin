#!/bin/bash
#SMART (Simple Miner Administration for Remote Terminals)

# Since LD_LIBRARY_PATH would not work, I did the following!
#(Though maybe I needed an export LD_LIBRARY_PATH in bash_profile)
#cd /usr/lib
#sudo ln -s /home/jondecker76/AMD-APP-SDK-v2.4-lnx32/lib/x86/libOpenCL.so libOpenCL.so
#sudo ln -s /home/jondecker76/AMD-APP-SDK-v2.4-lnx32/lib/x86/libOpenCL.so.1 libOpenCL.so.1
#sudo ln -s /home/jondecker76/AMD-APP-SDK-v2.4-lnx32/lib/x86/libamdocl32.so libamdocl32.so
#sudo ln -s /home/jondecker76/AMD-APP-SDK-v2.4-lnx32/lib/x86/libGLEW.so libGLEW.so
#sudo ln -s /home/jondecker76/AMD-APP-SDK-v2.4-lnx32/lib/x86/libglut.so libglut.so



#export LD_LIBRARY_PATH=/home/jondecker76/AMD-APP-SDK-v2.4-lnx32/lib/x86/:$LD_LIBRARY_PATH    
#export LD_LIBRARY_PATH=/home/jondecker76/phoenix/kernels/:$LD_LIBRARY_PATH  

. $HOME/smartcoin/smartcoin_ops.sh

# Start the backend service
$HOME/smartcoin/smartcoin_backend.sh &


Log "******************* NEW SMARTCOIN SESSION STARTED *******************" 

DeleteTemporaryFiles
echo "Starting SmartCoin..."

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
	
	echo "SCREEN RUNNING!"
	sleep 10
	exit
fi

echo "Starting sessions..."
screen -d -m -S $sessionName -t control "$HOME/smartcoin/smartcoin_control.sh"
screen -r $sessionName -X zombie ko
screen -r $sessionName -X chdir
screen -r $sessionName -X hardstatus on
screen -r $sessionName -X hardstatus alwayslastline
screen -r $sessionName -X hardstatus string '%{= kG}[ %{G}%H %{g}][%= %{= kw}%?%-Lw%?%{r}(%{W}%n*%f%t%?(%u
)%?%{r})%{w}%?%+Lw%?%?%= %{g}][%{B} %m/%d/%y %{W}%c %{g}]'

echo "Creating Windows"
# Create a new window for each machine
Q="SELECT pk_machine, name FROM machine;"
R=$(RunSQL "$Q")
for row in $R; do
	echo "..window"
	pk_machine=$(Field 1 "$row")
	machineName=$(Field 2 "$row")
	screen -r $sessionName -X screen -t $machineName $HOME/smartcoin/smartcoin_status.sh "$pk_machine"
done


clear
GotoStatus




