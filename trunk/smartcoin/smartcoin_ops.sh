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


UseDB "smartcoin"
Q="SELECT value from settings where data=\"current_profile\";"
R=$(RunSQL "$Q")
CURRENT_PROFILE=$(Field 1 "$R")
export CURRENT_PROFILE




startMiners() {
	local profile=$1
	
	# I don't think the commented section below is needed.
	# Only generate an auto profile IF A) you selct it in the "choose profile" section
	# Or B) you add a card, or worker AND the autoprofile is the current profile(in which case, KillMiners is called, the new profile generated, then StartMiners if called)
	#if [[ "$profile" == "-1" ]]; then
	#	GenAutoProfile
	#fi

	UseDB "smartcoin"
	Q="SELECT pk_map, fk_card, fk_miner, fk_worker from map WHERE fk_profile=$profile;"
	R=$(RunSQL "$Q")
	i=0

	for Row in $R; do	
		let i++
		local PK=$(Field 1 "$Row")
		local card=$(Field 2 "$Row")
		local miner=$(Field 3 "$Row")
		local worker=$(Field 4 "$Row")

		local cmd="$HOME/smartcoin/smartcoin_launcher.sh $card $miner $worker"
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
	local card
	local miner
	local worker
	local R
	local R2
	local R3
	Log "Generating Automatic Profile..."

	# Has the auto profile been added to the database yet?
	Q="INSERT IGNORE INTO profile (pk_profile,name,auto_allow) values (-1, \"Automatic\",1)";
	R=$(RunSQL "$Q")
	Log "$Q"
	# Next, erase any old autoprofile information from map
	Q="DELETE FROM map WHERE fk_profile=-1;"
	R=$(RunSQL "$Q")
	Log "$Q"
	Q="SELECT COUNT(*) from card;"
	R=$(RunSQL "$Q")
	local rows=$(Field 1 "$R")
	if [[ "$rows" != "0" ]]; then
		# There is at least one card
		Q="SELECT COUNT(*) from miner;"
		R=$(RunSQL "$Q")
		rows=$(Field 1 "$R")
		if [[ "$rows" != "0" ]]; then
			# There is at least one miner, and one card
			Q="SELECT COUNT(*) FROM worker;"
			R=$(RunSQL "$Q")
			rows=$(Field 1 "$R")
			if [[ "$rows" != "0" ]]; then
				# There is at least one worker, one miner and one card
				# Lets do the Automatic profile!  It works with the first
				# set up miner TODO: Make the miner selectable?

				Q="SELECT pk_miner FROM miner ORDER BY pk_miner ASC LIMIT 1;"
				R=$(RunSQL "$Q")
				miner=$(Field 1 "$R")
				
				Q="SELECT pk_card FROM card WHERE disabled=0;"
				R=$(RunSQL "$Q")
				for row in $R; do
					card=$(Field 1 "$row")
					Q="SELECT pk_worker FROM worker WHERE auto_allow;"
					R2=$(RunSQL "$Q")
					for row2 in $R2; do
						worker=$(Field 1 "$row2")
						Q="INSERT INTO map (fk_Card, fk_miner, fk_worker, fk_profile) values ($card,$miner,$worker,-1);"
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
		Log "No Cards Found!"
	fi
}

DeleteTemporaryFiles() {
	rm $HOME/smartcoin/.smartcoin*
}
