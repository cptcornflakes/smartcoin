#!/bin/bash

# This is the dumping ground for a lot of generalized functions, and is pretty much included in all other scripts.
# I really need to organize it a bit, clean it up, and maybe even separate it out into more logical files.


if [[ -n "$HEADER_smartcoin_ops" ]]; then
        return 0
fi
HEADER_smartcoin_ops="included"

# GLOBAL VARIABLES
# TODO: some of these will be added to the settings database table eventually.
# TODO: The installer can prompt for values, with sane defaults already entered
export sessionName="smartcoin"
export minerSession="miner"
commPipe=$HOME/smartcoin/smartcoin.cmd
statusRefresh="5"
MySqlHost="127.0.0.1"
MySqlPort=""
MySqlUser="smartcoin"
MySqlPassword="smartcoin"






ShowHeader() {
	echo "smartcoin Management System "    $(date)
	echo "--------------------------------------------------------------------------------"
}

MYSQL_DB_CRED=""
if [ "$MySqlHost" ] ; then MYSQL_DB_CRED="$MYSQL_DB_CRED -h$MySqlHost"; fi
if [ "$MySqlPort" ] ; then MYSQL_DB_CRED="$MYSQL_DB_CRED -P$MySqlPort"; fi
if [ "$MySqlUser" ] ; then MYSQL_DB_CRED="$MYSQL_DB_CRED -u$MySqlUser"; fi
if [ "$MySqlPassword" ] ; then MYSQL_DB_CRED="$MYSQL_DB_CRED -p$MySqlPassword"; fi
# Make sure to trim excess spaces
MYSQL_DB_CRED=`echo $MYSQL_DB_CRED`
export MYSQL_DB_CRED



RunSQL()
{
        local Q
        Q="$*"
        if [[ -n "$Q" ]]; then
                mysql -A -N "$SQL_DB" $MYSQL_DB_CRED -e "$Q;" | Field_Translate
        else
                mysql -A -N "$SQL_DB" $MYSQL_DB_CRED | Field_Translate
	        fi
}


#Usage:
#  Field=$(Field 1 "<SQL row>")
#Used in a 'for' loop to extract a field value from a FieldArray row
Field()
{
        local Row FieldNumber
        FieldNumber="$1"; shift
        Row="$*"
        echo "$Row" | cut -d$'\x01' -f"$FieldNumber" | tr $'\x02' ' '
}

#Usage:
#  UseDB "<DB name>"
#Changes the default database
UseDB()
{
        SQL_DB="$1"
        if [[ -z "$SQL_DB" ]]; then
                SQL_DB="$MySqlDBName"
        fi
}

UseDB "smartcoin"

Field_Translate()
{
        tr '\n\t ' $'\x20'$'\x01'$'\x02' | sed 's/ *$//'
}
Field_Prepare(){
	echo -ne "$1" | Field_Translate
}
FieldArrayAdd()
{
	menuItem=$(Field_Prepare "$1")
	echo "$menuItem "
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

	i=0
	for row in $FA; do
			
		let i++
		local key=$(Field 1 "$row")
		local pk_device=$(Field 2 "$row")
		local pk_miner=$(Field 3 "$row")
		local pk_worker=$(Field 4 "$row")
		echo "Starting miner $key!"
		local cmd="$HOME/smartcoin/smartcoin_launcher.sh $thisMachine $pk_device $pk_miner $pk_worker"
		if [[ "$i" == "1" ]]; then
			screen -d -m -S $minerSession -t "$key" $cmd
			screen -r $minerSession -X zombie ko
			screen -r $minerSession -X chdir
			screen -r $minerSession -X hardstatus on
			screen -r $minerSession -X hardstatus alwayslastline
			screen -r $minerSession -X hardstatus string '%{= kG}[ %{G}%H %{g}][%= %{= kw}%?%-Lw%?%{r}(%{W}%n*%f%t%?(%u)%?%{r})%{w}%?%+Lw%?%?%= %{g}][%{B} %m/%d/%y %{W}%c %{g}]'
		else
			#TODO: Use screen -S $minerSession?
			screen  -d -r $minerSession -X screen -t "$key" $cmd
		fi
	done
}

killMiners() {
	cmd=`screen -ls`
	DeleteTemporaryFiles
	screen -d -r $minerSession -X quit 
	cmd=`screen -ls`
	sleep 1
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
	local dte=`date "+%D %T"`
	echo -e "$dte\t$line\n" >> ~/smartcoin.log
}



DeleteTemporaryFiles() {
	rm -rf $HOME/smartcoin/.smartcoin* 2>/dev/null
	rm -rf $home/smartcoin/.Miner* 2>/dev/null
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
	# Return FieldArray containing windowKey, pk_device, pk_miner, pk_worker fields

	local thisMachine=$1
	local thisProfile=$(GetCurrentProfile "$thisMachine")
	local FieldArray
	
	local Donate=$(DonationActive) 


	if [[ "$Donate" ]]; then
		# AutoDonate time is right, lets auto-donate!
		# Generate the FieldArray via DonateProfile
		Log "Generating Donation Profile"
		FieldArray=$(GenDonationProfile "$thisMachine")
	elif [[ "$thisProfile" == "-2" ]]; then
		# Generous user manually chose the Donation profile!
		FieldArray=$(GenDonationProfile "$thisMachine")
		
	elif [[ "$thisProfile" == "-1" ]]; then
		# Generate the FieldArray via AutoProfile

		FieldArray=$(GenAutoProfile "$thisMachine")
	else
		# Generate the FieldArray via the database
		Q="SELECT CONCAT('Miner.',pk_profile_map), fk_device, fk_miner, fk_worker from profile_map WHERE fk_profile=$thisProfile ORDER BY fk_worker, fk_device"
        	FieldArray=$(RunSQL "$Q")
	fi
	

	echo $FieldArray	
}

GenAutoProfile()
{
	# Return FieldArray containing windowKey, pk_device, pk_miner, pk_worker fields
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
		
			FA=$FA$(FieldArrayAdd "Miner.$i	$thisDevice	$thisMiner	$thisWorker")
		done
	done

	echo "$FA"
}


GenDonationProfile()
{
	# Return FieldArray containing windowKey, pk_device, pk_miner, pk_worker fields
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
		
			FA=$FA$(FieldArrayAdd "Miner.$i	$thisDevice	$thisMiner	$thisDonationWorker")
		done
	done

	echo "$FA"
}

# In addition, line 26 in _launcher.sh needs changed to call this, instead
# of an sqlQuery
GetWorkerInfo()
{
	# Returns a FieldArray containing user, pass, pool.server, pool.port, pool.name
	local pk_worker=$1
	local FA


	# Handle special cases, such as special donation keys
	case "$pk_worker" in
	-1)
		# Deepbit donation worker
		FA=$(FieldArrayAdd "jondecker76@gmail.com_donate	donate	deepbit.net	8332	Deepbit.net (Donation)")
		;;
	-2)
		# Bitcoin.cz donation worker
		FA=$(FieldArrayAdd "jondecker76.donate	donate	mining.bitcoin.cz	8332	Bitcoin.cz (Donation)")
		;;
	-3)
		# BTCGuild donation worker
		FA=$(FieldArrayAdd "jondecker76_donate	donate	btcguild.com	8332	BTCGuild (Donation)")
		;;
	
	*)
		# Special no special cases, get information from the database
		Q="SELECT user,pass,pool.server, pool.port, pool.name from worker LEFT JOIN pool ON worker.fk_pool = pool.pk_pool WHERE pk_worker=$pk_worker;"
		FA=$(RunSQL "$Q")
		;;

	esac

	echo $FA
}

GetProfileName() {
	local thisMachine=$1

	local thisProfile=$(GetCurrentProfile $thisMachine)
	local Donate=$(DonationActive)

	if [[ "$Donate" ]]; then
		echo "Donation (via AutoDonate)"
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

GetCurrentDBProfile() {
	local thisMachine=$1

	UseDB "smartcoin"
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


AddTime()
{
	local baseTime=$1
	local minutesToAdd=$2

	local minutes=`expr $baseTime % 100` #${baseTime:2:3}
	local hours=`expr $baseTime / 100` #${baseTime:0:2}

	# Add minutes and keep between 0 and 60
	local totalMinutes=$(($minutes+$minutesToAdd))
	local carryOver=$(($totalMinutes/60))
	local correctedMinutes=$(($totalMinutes%60))
	correctedMinutes=`printf "%02d" $correctedMinutes`
	
	# Add remainder to hours
	local correctedHours=$(($hours+carryOver))
	correctedHours=$(($correctedHours%24))
	
	echo $correctedHours$correctedMinutes


}



DonationActive2() {
	echo ""
}


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

	curTime=`date +%k%M`

	ret=""

	if [[  "$duration" -gt "0" ]]; then
		if [[ "$start" -le "$end" ]]; then
			# Normal
			if [[ "$curTime" -ge "$start" ]]; then
				if [[ "$curTime" -lt "$end"  ]]; then
					ret="true"
				fi
			fi
		else
			 # Midnight carryover
			if [[ "$curTime" -ge "$start" ]]; then
				ret="true"
			fi
			if [[ "$curTime" -lt "$end" ]]; then
				ret="true"
			fi
		fi
	fi
	echo $ret

}

