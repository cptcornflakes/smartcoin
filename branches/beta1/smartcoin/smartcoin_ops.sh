#!/bin/bash

# This is the dumping ground for a lot of generalized functions, and is pretty much included in all other scripts.
# I really need to organize it a bit, clean it up, and maybe even separate it out into more logical files.


if [[ -n "$HEADER_smartcoin_ops" ]]; then
        return 0
fi
HEADER_smartcoin_ops="included"
if [[ $( dirname "$0" ) == "/usr/bin" ]]; then
	CUR_LOCATION=$(dirname $(readlink -f $( dirname "$0" )/smartcoin))
else
	CUR_LOCATION="$( cd "$( dirname "$0" )" && pwd )"
fi
. $CUR_LOCATION/sql_ops.sh

# SVN STUFF
GetRevision() {
  Q="SELECT value FROM settings WHERE data='dev_branch';"
  local branch=$(RunSQL "$Q")
  echo $(svn info $CUR_LOCATION/ | grep "^Revision" | awk '{print $2}')"($branch)"
}

GetRepo() {
	echo `svn info $CUR_LOCATION/ | grep "^URL" | awk '{print $2}'`
}
GetLocal() {
  echo $(svn info $CUR_LOCATION/ | grep "^Revision" | awk '{print $2}')
}
GetHead() {
	local repo="$1"
	echo `svn info $repo | grep "^Revision" | awk '{print $2}'`
}
GetStableHead() {
	local repo="$1"
	echo `svn info $repo/update.ver | grep "Last Changed Rev:" | awk '{print $4}'`
}

FormatOutput() {
	local hashes=$1
	local accepted=$2
	local rejected=$3
	local percentage=$4

	Q="SELECT value FROM settings WHERE data='format';"
	local format=$(RunSQL "$Q")

	format=${format//<#hashrate#>/$hashes}
	format=${format//<#accepted#>/$accepted}
	format=${format//<#rejected#>/$rejected}
	format=${format//<#rejected_percent#>/$percentage}
	echo "$format"
	
}

# GLOBAL VARIABLES
# TODO: some of these will be added to the settings database table eventually.
# TODO: The installer can prompt for values, with sane defaults already entered
export sessionName="smartcoin"
export minerSession="miner"
export REVISION=$(GetRevision)
RESTART_REQ=""



STABLE=1
EXPERIMENTAL=2

commPipe=$HOME/.smartcoin/smartcoin.cmd
statusRefresh="5"
MySqlHost="127.0.0.1"
MySqlPort=""
MySqlUser="smartcoin"
MySqlPassword="smartcoin"





RunningOnLinuxcoin() {
	if [[ "$HOSTNAME" == "linuxcoin" ]]; then
		echo "1"
	else
		echo "0"
	fi
}

ShowHeader() {
	echo "smartcoin Management System r$REVISION"    $(date)
	echo "--------------------------------------------------------------------------------"
}


tableIsEmpty() {
	local thisTable=$1
	local whereClause=$2

	Q="SELECT COUNT(*) FROM $thisTable $whereClause;"
	R=$(RunSQL "$Q")
	res=$(Field 1 "$R")

	if [[ "$res" == "0" ]]; then
		echo "True"
	else
		echo ""
	fi
}



startMiners() {
	local thisMachine=$1
	
	local FA=$(GenCurrentProfile "$thisMachine")

	# Lets start up the miner session with a dummy window, so that we can set options,
	# such as zombie mode	
	screen -dmS $minerSession -t "miner-dummy"
	sleep 2
	screen -r $minerSession -X zombie ko
	screen -r $minerSession -X chdir
	screen -r $minerSession -X hardstatus on
	screen -r $minerSession -X hardstatus alwayslastline
	screen -r $minerSession -X hardstatus string '%{= kG}[ %{G}%H %{g}][%= %{= kw}%?%-Lw%?%{r}(%{W}%n*%f%t%?(%u)%?%{r})%{w}%?%+Lw%?%?%= %{g}][%{B} %m/%d/%y %{W}%c %{g}]'

	# Start all of the miner windows
	for row in $FA; do
		local key=$(Field 2 "$row")
		local pk_device=$(Field 3 "$row")
		local pk_miner=$(Field 4 "$row")
		local pk_worker=$(Field 5 "$row")
		Log "Starting miner $key!" 1
		local cmd="$CUR_LOCATION/smartcoin_launcher.sh $thisMachine $pk_device $pk_miner $pk_worker"
		screen  -d -r $minerSession -X screen -t "$key" $cmd
	done

	# The dummy window has served its purpose, lets get rid of it so we don't confuse the user with a blank window!
	screen -r $minerSession -p "miner-dummy" -X kill
}


killMiners() {
	Log "Killing Miners...."
	DeleteTemporaryFiles
	screen -d -r $minerSession -X quit 
	sleep 2
}

GotoStatus() {
	attached=`screen -ls | grep $sessionName | grep Attached`

	if [[ "$attached" != "" ]]; then
		screen  -d -r -p 0
	else
		screen  -r $sessionName -p 0
	fi
	
}


Log() {
	local line="$1"
  local announce="$2"
  
	local dte=`date "+%D %T"`
	echo -e "$dte\t$line\n" >> $HOME/.smartcoin/smartcoin.log
   
  if [[ "$announce" == "1" ]]; then
    echo -e $line
  fi
}

RotateLogs() {
	mv $HOME/.smartcoin/smartcoin.log $HOME/.smartcoin/smartcoin.log.previous
}


DeleteTemporaryFiles() {
	rm -rf /tmp/smartcoin* 2>/dev/null
}




SetDefaultMiner() {
	local thisMachine=$1
	local thisMiner=$2

	Q="UPDATE miner SET default_miner=0 WHERE fk_machine=$thisMachine;"
	RunSQL "$Q"

	Q="Update miner set default_miner=1 WHERE pk_miner=$thisMiner;"
	RunSQL "$Q"
}


### PROFILE RELATED FUNCTIONS ###
# TODO:  These should be in their own include file I think
GetCurrentProfile()
{
	local thisMachine=$1

	local Donate=$(DonationActive)

	if [[ "$Donate" ]]; then
		echo "donate"
	else
		Q="SELECT fk_profile FROM current_profile WHERE fk_machine=$MACHINE;"
		R=$(RunSQL "$Q")
		echo $(Field 1 "$R")
	fi
}
GenCurrentProfile()
{
	# Return FieldArray containing pk_profile, windowKey, pk_device, pk_miner, pk_worker fields

	local thisMachine=$1
	local thisProfile=$(GetCurrentProfile "$thisMachine")
	local FieldArray
	
	local Donate=$(DonationActive) 


	if [[ "$Donate" ]]; then
		# AutoDonate time is right, lets auto-donate!
		# Generate the FieldArray via DonateProfile
		Log "Generating Donation Profile"
		FieldArray=$(GenDonationProfile "$thisMachine")
	elif [[ "$thisProfile" == "-3" ]]; then
		# Generate the FieldArray via Failover
		FieldArray=$(GenFailoverProfile "$thisMachine")
	elif [[ "$thisProfile" == "-2" ]]; then
		# Generous user manually chose the Donation profile!
		FieldArray=$(GenDonationProfile "$thisMachine")
		
	elif [[ "$thisProfile" == "-1" ]]; then
		# Generate the FieldArray via AutoProfile

		FieldArray=$(GenAutoProfile "$thisMachine")
	else
		# Generate the FieldArray via the database
		Q="SELECT fk_profile, 'Miner.' || pk_profile_map, fk_device, fk_miner, fk_worker from profile_map WHERE fk_profile=$thisProfile ORDER BY fk_worker ASC, fk_device ASC"
        	FieldArray=$(RunSQL "$Q")
	fi
	

	echo $FieldArray	
}

GenAutoProfile()
{
	# Return FieldArray containing pk_profile, windowKey, pk_device, pk_miner, pk_worker fields
	local thisMachine=$1

	local FA
	local i=0

	Q="SELECT pk_miner FROM miner WHERE fk_machine=$thisMachine AND default_miner=1;"
	R=$(RunSQL "$Q")
	thisMiner=$(Field 1 "$R")

	Q="SELECT pk_worker FROM worker WHERE auto_allow=1 ORDER BY fk_pool ASC;"
	R=$(RunSQL "$Q")

	
	for thisWorker in $R; do
		Q="SELECT pk_device from device WHERE fk_machine=$thisMachine AND disabled=0 ORDER BY device ASC;"
		R2=$(RunSQL "$Q")
		for thisDevice in $R2; do
			let i++
		
			FA=$FA$(FieldArrayAdd "-1	Miner.$i	$thisDevice	$thisMiner	$thisWorker")
		done
	done

	echo "$FA"
}


GenFailoverProfile()
{
	# Return FieldArray containing pk_profile, windowKey, pk_device, pk_miner, pk_worker fields
	local thisMachine=$1
	local FA
	local i=0

	# Return, in order, all failover profiles to the point that one not marked as "down" is found, and return them all.
	local firstActive=""
	
	Q="SELECT pk_miner FROM miner WHERE fk_machine=$thisMachine AND default_miner=1;"
	R=$(RunSQL "$Q")
	thisMiner=$(Field 1 "$R")

	Q="SELECT pk_profile, name, down FROM profile WHERE fk_machine='$thisMachine' ORDER BY failover_order, pk_profile;"
	R=$(RunSQL "$Q")

	for row in $R; do
		local thisProfile=$(Field 1 "$row")
		local isDown=$(Field 3 "$row")
		# Build the FieldArray until we get a profile that isn't down
		Q2="SELECT fk_device, fk_miner, fk_worker from profile_map WHERE fk_profile='$thisProfile' ORDER BY fk_worker ASC, fk_device ASC"
		R2=$(RunSQL "$Q2")
		for row2  in $R2; do
			let i++
			local thisDevice=$(Field 1 "$row2")
			local thisMiner=$(Field 2 "$row2")
			local thisWorker=$(Field 3 "$row2")

			FA=$FA$(FieldArrayAdd "$thisProfile	Miner.$i	$thisDevice	$thisMiner	$thisWorker")
		done
		if [[ "$isDown" == "0" ]]; then
			# We found the first failover profile that isn't down, lets get out of here
			break
		fi
	done

	echo "$FA"

}
GenDonationProfile()
{
	# Return FieldArray containing pk_profile, windowKey, pk_device, pk_miner, pk_worker fields
	local thisMachine=$1
	local FA
	local i=0
	local donationWorkers="-3 -2 -1"

	
	Q="SELECT pk_miner FROM miner WHERE fk_machine=$thisMachine AND default_miner=1;"
	R=$(RunSQL "$Q")
	thisMiner=$(Field 1 "$R")


	

	for thisDonationWorker in $donationWorkers; do
		Q="SELECT pk_device from device WHERE fk_machine=$thisMachine AND disabled=0 ORDER BY device ASC;"
		R=$(RunSQL "$Q")
		for thisDevice in $R; do
		
			let i++
		
			FA=$FA$(FieldArrayAdd "-2	Miner.$i	$thisDevice	$thisMiner	$thisDonationWorker")
		done
	done

	echo "$FA"
}

# alternate between donating to smartcoin and linuxcoin, if linuxcoin is installed.
# This "flag" will be xor'd with 1 every other time
lastDonation="0"
DONATION_ENTITY="0"
CycleDonations() {
	local currentDonation="$1"
	
	local onLinuxcoin

	onLinuxcoin=$(RunningOnLinuxcoin)
	
	if [[ "onLinuxcoin" == "1" ]]; then
		if [[ "$currentDonation" == "0" ]]; then
			if [[ "$lastDonation" != "0" ]]; then
				# The donation state has changed from donating to not donating.
				# Lets cycle through the list of donation entities, so that the next entity gets a dontation on the next donation cycle (everyone gets their turn)
				# Note: right now there are only 2 donation entities (0 and 1), so a simple xor will do. If more are added in the future, then I will deal with that then...				
			
				let DONATION_ENTITY=DONATION_ENTITY^1
			fi
		fi
	fi

	lastDonation=$currentDonation
}
GetWorkerInfo()
{
	# Returns a FieldArray containing user, pass, pool.server, pool.port, pool.name
	local pk_worker=$1
	local FA


	# Handle special cases, such as special donation keys
	case "$pk_worker" in
	-1)
		case "$DONATION_ENTITY" in
		0)
			# smartcoin Deepbit donation worker
			FA=$(FieldArrayAdd "jondecker76@gmail.com_donate	donate	deepbit.net	8332	Deepbit.net (Donation to smartcoin)")
			;;
		1)
			# linuxcoin donation worker #1
			FA=$(FieldArrayAdd "zarren2@hotmail.co.uk_1	password	deepbit.net	8332	Deepbit.net (Donation to linuxcoin)")
			;;
		esac
		;;
	-2)
		case "$DONATION_ENTITY" in
		0)
			# smartcoin BTCMine donation worker
			FA=$(FieldArrayAdd "jondecker76@donate	donate	btcmine.com	8332	BTCMine (Donation to smartcoin)")
			;;
		1)
			# linuxcoin donation worker #2
			FA=$(FieldArrayAdd "zarren2@hotmail.co.uk_2	password	deepbit.net	8332	Deepbit.net (Donation to linuxcoin)")
			;;
		esac
		
		;;
	-3)
		case "$DONATION_ENTITY" in
		0)
			# BTCGuild donation worker
			FA=$(FieldArrayAdd "jondecker76_donate	donate	btcguild.com	8332	BTCGuild (Donation to smartcoin)")
			;;
		1)
			# linuxcoin donation worker #3
			FA=$(FieldArrayAdd "zarren2@hotmail.co.uk_3	password	deepbit.net	8332	Deepbit.net (Donation to linuxcoin)")
			;;
		esac
		;;
	
	*)
		# No special cases, get information from the database
		Q="SELECT user,pass,pool.server, pool.port, pool.name from worker LEFT JOIN pool ON worker.fk_pool = pool.pk_pool WHERE pk_worker=$pk_worker;"
		FA=$(RunSQL "$Q")
		;;

	esac

	echo $FA
}



GetCurrentDBProfile() {
	local thisMachine=$1

	UseDB "smartcoin.db"
	Q="SELECT fk_profile from current_profile WHERE fk_machine=$thisMachine;"
	R=$(RunSQL "$Q")
	echo $(Field 1 "$R")
}
SetCurrentProfile() {
	local thisMachine=$1
	local thisProfile=$2

	Q="DELETE FROM current_profile WHERE fk_machine=$thisMachine;"
	RunSQL "$Q"
	Q="INSERT INTO current_profile (fk_machine,fk_profile) VALUES ($thisMachine,$thisProfile);"
	RunSQL "$Q"
}

DiffTime()
{
	local startTime=$1
	local endTime=$2

	startTime=$(seq $startTime $startTime)
	endTime=$(seq $endTime $endTime)

	# Convert both to minutes
	hours=`expr $startTime / 100`
	minutes=`expr $startTime % 100`
	let hourMins=$hours*60
	let startMinutes=$hourMins+$minutes

	hours=`expr $endTime / 100`
	minutes=`expr $endTime % 100`
	let hourMins=$hours*60
	let endMinutes=$hourMins+$minutes

	echo `expr $endMinutes - $startMinutes`


}	

AddTime()
{
	local baseTime=$1
	local minutesToAdd=$2

	basetime=$(seq $baseTime $baseTime)
	local minutes=`expr $baseTime % 100` #${baseTime:2:3}
	local hours=`expr $baseTime / 100` #${baseTime:0:2}


	# Add minutes and keep between 0 and 60
	local totalMinutes=$(($minutes+$minutesToAdd))
	local carryOver=$(($totalMinutes/60))
	local correctedMinutes=$(($totalMinutes%60))
	correctedMinutes=`printf "%02d" $correctedMinutes` # pad with at least one zero if needed
	
	# Add remainder to hours
	local correctedHours=$(($hours+carryOver))
	correctedHours=$(($correctedHours%24))
	
	echo $correctedHours$correctedMinutes


}



# DonationActive returns either nothing if the donation isn't active,
# or a positive number representing the number of minutes remaining in the donation cycle
DonationActive() {
	Q="SELECT value FROM settings WHERE data='donation_start';"
	R=$(RunSQL "$Q")
	local start=$(Field 1 "$R")
	
	Q="SELECT value FROM settings WHERE data='donation_time';"
	R=$(RunSQL "$Q")
	local duration=$(Field 1 "$R")

	if [[ "$duration" == "" ]]; then
		duration="0"
	fi
	if [[ "$start" == "" ]]; then
		let startTime_hours=$RANDOM%23
		let startTime_minutes=$RANDOM%59
		startTime=$startTime_hours$startTime_minutes
		Q="UPDATE settings SET value='$startTime' WHERE data='donation_start'"
		RunSQL "$Q"
	fi

	local end=$(AddTime "$start" "$duration")
	
	local curTime=`date +%k%M`
	curTime=$(seq $curTime $curTime)


	ret=""

	if [[  "$duration" -gt "0" ]]; then
		if [[ "$start" -le "$end" ]]; then
			# Normal
			if [[ "$curTime" -ge "$start" ]]; then
				if [[ "$curTime" -lt "$end"  ]]; then
					#ret="true"
					ret=$(DiffTime $curTime $end)
				fi
			fi
		else
			 # Midnight carryover
			if [[ "$curTime" -ge "$start" ]]; then
				#ret="true"
				local minTilMid=$(DiffTime $curTime "2400")
				ret=$(AddTime $end $minTilMid)
				ret=$(seq $ret $ret)
			fi
			if [[ "$curTime" -lt "$end" ]]; then
				ret=$(DiffTime $curTime $end)
				
			fi
		fi
	fi

	CycleDonations "$ret"
	echo $ret

}

GetProfileName() {
	local thisMachine=$1

	local thisProfile=$(GetCurrentProfile $thisMachine)
	local Donate=$(DonationActive)

	if [[ "$Donate" ]]; then
		echo "Donation (via AutoDonate)  - $Donate minutes remaining."
	elif [[ "$thisProfile" == "-3" ]]; then
		echo "Failover"
	elif [[ "$thisProfile" == "-2" ]]; then
		echo "Donation (Manual selection)"
	elif [[ "$thisProfile" == "-1" ]]; then
		echo "Automatic"
	else
		Q="SELECT name FROM profile WHERE pk_profile=$thisProfile;"
		R=$(RunSQL "$Q")
		echo $(Field 1 "$R")
	fi
}

NotImplemented()
{
	clear
	ShowHeader
	echo "This feature has not been implemented yet!"
	sleep 3
}
DisplayMenu()
{	
	local fieldArray="$1"

	for item in $fieldArray; do
	num=$(Field 2 "$item")
	listing=$(Field 3 "$item")
	echo -e  "$num) $listing"
	done


}
#var=$(GetMenuSelection "$M" "default value")
GetMenuSelection()
{
	local fieldArray=$1
	local default=$2

	read -e -i "$default" chosen

	for item in $fieldArray; do
		choice=$(Field 2 "$item")
		if [[ "$chosen" == "$choice" ]]; then
			echo $(Field 1 "$item")
			return 0
		fi
	done
	echo "ERROR"
}

# GetPrimaryKeySelection var "$Q" "$E" "default value"
GetPrimaryKeySelection()
{
	local _ret=$1
	local Q=$2
	local msg=$3
	local default=$4
	local fieldArray=$5	# You can pass in a pre-populated field array to add on to


	local PK	#Primary key of name (not shown in menu)
	local Name	#Name displayed in menu
	local M=""	#Menu FieldArray
	local i=0		#Index count


	if [[ "$fieldArray" ]]; then
		for thisRecord in $fieldArray; do
			
			PK=$(Field 1 "$thisRecord")
			index=$(Field 2 "$thisRecord")
			Name=$(Field 3 "$thisRecord")
			M=$M$(FieldArrayAdd "$PK	$index	$Name")
		done
		i=$index
	fi

	

	UseDB "smartcoin.db"
	R=$(RunSQL "$Q")
	for Row in $R; do
		let i++
		PK=$(Field 1 "$Row")
		Name=$(Field 2 "$Row")
		M=$M$(FieldArrayAdd "$PK	$i	$Name")
	done
	DisplayMenu "$M"
	echo "$msg"
	PK="ERROR"
	until [[ "$PK" != "ERROR" ]]; do
		PK=$(GetMenuSelection "$M" "$default")
		if [[ "$PK" == "ERROR" ]]; then
			echo "Invalid selection. Please try again."
		fi
	done
	eval $_ret="'$PK'"
}
#GetYesNoSelection var "$E" "default value"
GetYesNoSelection() {                                                                                
	resp="-1"  
	local available

	local _retyn=$1
	local msg=$2
	local default=$3
	
	if [[ "$default" == "1" ]]; then
		default="y"
	elif [[  "$default" == "0" ]]; then
		default="n"
	else
		default=""
	fi

	echo -e "$msg"                                             
	until [[ "$resp" != "-1" ]]; do                                         
		read -e -i "$default" available                                                  
		                                                        
		available=`echo $available | tr '[A-Z]' '[a-z]'`                
		if [[ "$available" == "y" ]]; then                              
			resp=1                                                
		elif [[ "$available" == "n" ]]; then                            
			resp=0                                                
		else                                                            
			echo "Invalid response!"                                
		fi                                                              
	done    
	
	eval $_retyn="'$resp'"
}
DisplayError()
{
	msg=$1
	dly=$2
	clear
	ShowHeader

	echo "ERROR! $msg"
	sleep $dly
	#test
}

AddEditDelete()
{
	# TODO: Add view option
	msg=$1
	clear
	ShowHeader

	echo "Would you like to (A)dd, (E)dit or (D)elete $msg?"
	echo "(X) to exit back to the main menu."
#test
}
GetAEDSelection()
{
	# TODO: Add view option
	read chosen
	chosen=`echo $chosen | tr '[A-Z]' '[a-z]'`
	case "$chosen" in
	a)
		echo "ADD"
		;;
	e)
		echo "EDIT"
		;;
	d)
		echo "DELETE"
		;;
  x)
    echo "EXIT"
    ;;
	*)
		echo "ERROR"
		;;	
	esac
}

# ### END UI HELPER FUNCTIONS ###







# Lets fix up our $LD_LIBRARY_PATH
Q="SELECT value FROM settings WHERE data='AMD_SDK_location';"
R=$(RunSQL "$Q")
amd_sdk_location=$(Field 1 "$R")

Q="SELECT value FROM settings WHERE data='phoenix_location';"
R=$(RunSQL "$Q")
phoenix_location=$(Field 1 "$R")

if [[ "$amd_sdk_location" ]]; then
	export LD_LIBRARY_PATH=$amd_sdk_location:$LD_LIBRARY_PATH
fi
if [[ "$phoenix_location" ]]; then
	export LD_LIBRARY_PATH=$phoenix_location:$LD_LIBRARY_PATH
fi	


