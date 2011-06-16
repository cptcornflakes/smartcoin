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



#LD_LIBRARY_PATH=/home/jondecker76/AMD-APP-SDK-v2.4-lnx32/lib/x86/:$LD_LIBRARY_PATH    
#LD_LIBRARY_PATH=/home/jondecker76/phoenix/kernels/:$LD_LIBRARY_PATH  

. $HOME/smartcoin/smartcoin_ops.sh



running=`screen -ls | grep $sessionName`

if [[ "$running" ]]; then
	screen -x $sessionName -p status
	exit
fi

screen -d -m -S $sessionName -t status "$HOME/smartcoin/smartcoin_status.sh"
screen -r $sessionName -X zombie ko
screen -r $sessionName -X chdir
screen -r $sessionName -X hardstatus on
screen -r $sessionNamer -X hardstatus alwayslastline
screen -r $sessionName -X hardstatus string '%{= kG}[ %{G}%H %{g}][%= %{= kw}%?%-Lw%?%{r}(%{W}%n*%f%t%?(%u
)%?%{r})%{w}%?%+Lw%?%?%= %{g}][%{B} %d/%m %{W}%c %{g}]'
screen -r $sessionName -X screen -t monitor
screen -r $sessionName -X screen -t control $HOME/smartcoin/smartcoin_control.sh
screen -r $sessionName -X screen -t bitcoind ./bitcoin-0.3.22/bin/32/bitcoind
screen -r $sessionName -X screen -t namecoind 


UseDB "smartcoin"
Q="SELECT value FROM settings WHERE data=\"current_profile\";"
R=$(RunSQL "$Q")
CURRENT_PROFILE=$(Field 1 "$R")
startMiners $CURRENT_PROFILE

GotoStatus




