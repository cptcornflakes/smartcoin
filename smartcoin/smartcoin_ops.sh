#!/bin/bash

if [[ -n "$HEADER_smartcoin_ops" ]]; then
        return 0
fi
HEADER_smartcoin_ops="included"

. $HOME/smartcoin/smartcoin_config.sh
# Define the command pipe to the backend
commPipe=$HOME/smartcoin/.smartcoin.cmd

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

CSQL_DIR="/var/run/SQL_Ops"
CSQL_ID=""

#Example:
#  QUERY="SELECT field1, field2 FROM table"
#  RESULT=$(RunSQL "$QUERY")
#  for ROW in $RESULT; do
#      FIELD1=$(Field 1 "$ROW")
#      FIELD2=$(Field 2 "$ROW")
#      echo "Field1: $FIELD1; Field2: $FIELD2"
#  done

#Usage:
#  Var=$(RunSQL "<SQL query>")
#Returns resulting rows in $Var; you can iterate through them using 'for'
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
#Used in a 'for' loop to extract a field value from a row
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

UseDB "$MySqlDBName"

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

GetCurrentProfile() {
	local thisMachine=$1

	UseDB "smartcoin"
	Q="SELECT fk_profile from current_profile WHERE fk_machine=$thisMachine;"
	R=$(RunSQL "$Q")
	echo $(Field 1 "$R")
}



startMiners() {
	# TODO: Should we pass in the machine PK, then use that to get the current_profile?
	local profile=$1

	# Get the machine number associated with the profile
	Q="SELECT fk_machine FROM profile WHERE pk_profile=$profile;"
	R=$(RunSQL "$Q")
	local machine=$(Feild 1 "$R")
	
	# TODO: since any profile_map with a defined fk_profile already limits to teh correct machine,
	# the $machine var will be used to invoke ssh for remote machines
	UseDB "smartcoin"
	Q="SELECT pk_profile_map, fk_device, fk_miner, fk_worker from profile_map WHERE fk_profile=$profile;"
	R=$(RunSQL "$Q")
	i=0

	for Row in $R; do	
		let i++
		local PK=$(Field 1 "$Row")
		local device=$(Field 2 "$Row")
		local miner=$(Field 3 "$Row")
		local worker=$(Field 4 "$Row")

		local cmd="$HOME/smartcoin/smartcoin_launcher.sh $device $miner $worker"
		if [[ "$i" == "1" ]]; then
		screen -d -m -S $minerSession -t "smartcoin.$PK" $cmd
		screen -r $minerSession -X zombie ko
		screen -r $minerSession -X chdir
		screen -r $minerSession -X hardstatus on
		screen -r $minerSession -X hardstatus alwayslastline
		screen -r $minerSession -X hardstatus string '%{= kG}[ %{G}%H %{g}][%= %{= kw}%?%-Lw%?%{r}(%{W}%n*%f%t%?(%u
		)%?%{r})%{w}%?%+Lw%?%?%= %{g}][%{B} %d/%m %{W}%c %{g}]'
		else
		screen  -d -r $minerSession -X screen -t "smartcoin.$PK" $cmd

		fi
		sleep 1
	done
}

killMiners() {
	local profile=$1
	DeleteTemporaryFiles
	screen -d -r $minerSession -X quit


	sleep 1
}

GotoStatus() {
	attached=`screen -ls | grep $sessionName | grep Attached`

	if [[ "$attached" != "" ]]; then
		screen  -d -r -p status
	else
		screen  -r $sessionName -p status
	fi
	
}

Log() {
	local line
	line="$1"
	echo -e "$line\n" >> ~/smartcoin.log
}

GenAutoProfile() {
	#TODO: SHould this be dynamic??
	local machine=$1 #TODO: not used yet
	local device
	local miner
	local worker
	local R
	local R2
	local R3
	Log "Generating Automatic Profile..."

	#TODO: auto_profile primary keys will be -1000-$machinePK when multi-machine support is in
	# Has the auto profile been added to the database yet?
	Q="INSERT IGNORE INTO profile (pk_profile,name,fk_machine,auto_allow) values (-1, 'Automatic',1,1)";
	R=$(RunSQL "$Q")
	Log "$Q"
	# Next, erase any old autoprofile information from profile_map
	# TODO: shouled entries be stored in the negative range?
	Q="DELETE FROM profile_map WHERE fk_profile=-1;"
	R=$(RunSQL "$Q")
	Log "$Q"
	Q="SELECT COUNT(*) from device WHERE fk_machine=1;"
	R=$(RunSQL "$Q")
	local rows=$(Field 1 "$R")
	if [[ "$rows" != "0" ]]; then
		# There is at least one device
		Q="SELECT COUNT(*) from miner WHERE fk_machine=1;"
		R=$(RunSQL "$Q")
		rows=$(Field 1 "$R")
		if [[ "$rows" != "0" ]]; then
			# There is at least one miner, and one device
			Q="SELECT COUNT(*) FROM worker;"
			R=$(RunSQL "$Q")
			rows=$(Field 1 "$R")
			if [[ "$rows" != "0" ]]; then
				# There is at least one worker, one miner and one device
				# Lets do the Automatic profile!  It works with the first
				# set up miner TODO: Make the miner selectable?

				Q="SELECT pk_miner FROM miner WHERE fk_machine=1 ORDER BY pk_miner ASC LIMIT 1;"
				R=$(RunSQL "$Q")
				miner=$(Field 1 "$R")
				
				Q="SELECT pk_device FROM device WHERE fk_machine=1 AND disabled=0;"
				R=$(RunSQL "$Q")
				for row in $R; do
					device=$(Field 1 "$row")
					Q="SELECT pk_worker FROM worker WHERE auto_allow;"
					R2=$(RunSQL "$Q")
					for row2 in $R2; do
						worker=$(Field 1 "$row2")
						Q="INSERT INTO profile_map (fk_device, fk_miner, fk_worker, fk_profile) values ($device,$miner,$worker,-1);"
						R3=$(RunSQL "$Q")
					done
				done
			else
				Log "No Workers Found!"
			fi
		else
			Log "No miners found!"
		fi
	else
		Log "No devices Found!"
	fi
}

GenerateDonationProfile() {
	thisMachine=$1

	# Make the special donation profile
	Q="INSERT INTO profile (pk_profile,fk_machine,name,auto_allow) VALUES (-100,$thisMachine,'Donating!',1);"
	RunSQL "$Q"

	# Deepbit Donation Worker
	Q="INSERT INTO worker (pk_worker,fk_pool,name,user,pass,auto_allow,disabled) VALUES (-1,1,'Donate','jondecker76@gmail.com_donate','donate',1,0);"
	RunSQL "$Q"

	# Bitcoin.cz Donation Worker
	Q="INSERT INTO worker (-2,pk_worker,fk_pool,name,user,pass,auto_allow,disabled) VALUES (2,'Donate','jondecker76.donate','donate',1,0);"
	RunSQL "$Q"	

	# BTCGuild Donation Worker
	Q="INSERT INTO worker (-3,pk_worker,fk_pool,name,user,pass,auto_allow,disabled) VALUES (3,'Donate','jondecker76_donate','donate',1,0);"
	RunSQL "$Q"

	# BTCMine Donation Worker	
	Q="INSERT INTO worker (-4,pk_worker,fk_pool,name,user,pass,auto_allow,disabled) VALUES (4,'Donate','jondecker76@donate','donate',1,0);"
	RunSQL "$Q"	

	# Update the profile_map
	Q="DELETE FROM profile_map WHERE fk_profile=-100 AND fk_machine=$thisMachine"
	RunSQL "$Q"

	Q="SELECT * FROM device WHERE disabled=0;"
	R=$(RunSQL "$Q")
	
	for row in $R; do
		thisDevice=$(Field 1 "$row")
		Q="INSERT INTO profile_map (fk_device,fk_miner,fk_worker,fk_profile,fk_machine) VALUES ($thisDevice,1,-1,-100,$thisMachine)";
		RunSQL "$Q"
		Q="INSERT INTO profile_map (fk_device,fk_miner,fk_worker,fk_profile,fk_machine) VALUES ($thisDevice,1,-1,-100,$thisMachine)";
		RunSQL "$Q"
		Q="INSERT INTO profile_map (fk_device,fk_miner,fk_worker,fk_profile,fk_machine) VALUES ($thisDevice,1,-1,-100,$thisMachine)";
		RunSQL "$Q"
		Q="INSERT INTO profile_map (fk_device,fk_miner,fk_worker,fk_profile,fk_machine) VALUES ($thisDevice,1,-1,-100,$thisMachine)";
		RunSQL "$Q"	
	done
}

DeleteTemporaryFiles() {
	# TODO: don't delete the commpipe!
	rm $HOME/smartcoin/.smartcoin*
}
