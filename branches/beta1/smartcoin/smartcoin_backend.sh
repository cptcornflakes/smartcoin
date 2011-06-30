#!/bin/bash

# NOT USED
# This is reserverd for future use.
# There are some things that may need to be done from outside of the current shell
# This script is for those occations.
# Most of the programming here was for testing purposes...


. $HOME/smartcoin/smartcoin_ops.sh

# Create the command pipe to the backend...                                     
trap "rm -f $commPipe" EXIT                                                    
                                                                                
if [[ ! -p $commPipe ]]; then                                                   
    mkfifo $commPipe                                                          
fi                                

while read cmd <$commPipe; do

	case "$cmd" in

	attach)
		# Attach to screen session
		read session <$commPipe
		screen -d -r $session
		;;
	detach)
		# Detach from screen
		screen -d $sessionName
		screen -d $minerSession
		;;
	goto_window)
		read session <$commPipe
		read window <$commPipe
		screen -d -r $session -p $window
		;;
	exit)
		screen -d -r $sessionName -X quit
		screen -d -r $minerSession -X quit
		exit
		;;
	restart)
		# Restart smartcoin
		screen -d -r $sessionName -X quit
		screen -d -r $minerSession -X quit
		smartcoin
		exit
		;;
	test)
		echo "Test Successful!"
	esac
done

echo "Exiting!"
