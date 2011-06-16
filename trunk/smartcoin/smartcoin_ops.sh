#!/bin/bash

if [[ -n "$HEADER_smartcoin_ops" ]]; then
        return 0
fi
HEADER_smartcoin_ops="included"

. $HOME/smartcoin/smartcoin_config.sh

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

RunCSQL()
{
        local Q Q_id
        Q="$*"

        if [[ "$CSQL_ID" == "" ]] ;then
                RunSQL "$Q"
                return
        fi
	
        Q_id=$(echo "$Q" | sha1sum - | cut -d' ' -f1)
        if [[ ! -f "$CSQL_DIR/$CSQL_ID/$Q_id" ]] ;then
                RunSQL "$Q" > "$CSQL_DIR/$CSQL_ID/$Q_id"
        fi

        cat "$CSQL_DIR/$CSQL_ID/$Q_id"
}

PurgeCSQL() {
        CSQL_ID="$1"
        rm -rf "$CSQL_DIR/$CSQL_ID/"*
}

InitCSQL() {
        CSQL_ID="$1"
        mkdir -p "$CSQL_DIR/$CSQL_ID"
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



UseDB "smartcoin"
Q="SELECT value from settings where data=\"current_profile\";"
R=$(RunSQL "$Q")
CURRENT_PROFILE=$(Field 1 "$R")
export CURRENT_PROFILE




startMiners() {
	local profile=$1
	
	UseDB "smartcoin"
	Q="SELECT pk_map, fk_card, fk_miner, fk_worker from map WHERE fk_profile=$profile;"
	R=$(RunSQL "$Q")

	for Row in $R; do
		local PK=$(Field 1 "$Row")
		local card=$(Field 2 "$Row")
		local miner=$(Field 3 "$Row")
		local worker=$(Field 4 "$Row")

		local cmd="$HOME/smartcoin/smartcoin_launcher.sh $card $miner $worker"
		screen  -x $sessionName -X screen -t "smartcoin.$PK" $cmd
	done
}

killMiners() {
	local profile=$1

	UseDB "smartcoin"
	Q="SELECT pk_map from map WHERE fk_profile=$profile;"
	R=$(RunSQL "$Q")


	for Row in $R; do
		local PK=$(Field 1 "$Row")
		screen -x $sessionName -p "smartcoin.$PK" -X kill
	done
}

GotoStatus() {
	screen -r $sessionName -p status 
}

GenAutoProfile() {

#make sure the auto profile (special primary key -1) exists...
Q="SELECT pk_profile FROM profile where pk_profile=-1;"
R=$(RunSQL "$Q")
if [[ "$R" == "" ]]; then
     Q="INSERT INTO profile (pk_profile, name, disabled) values (-1,\"Automatic\",0);"
     R=$(RunSQL "$Q")

fi

# populate the map table///  First, erase any old autoprofile information from map
Q="DELETE FROM map WHERE fk_profile=-1;"
R=$(RunSQL "$Q")

# TODO:  Generate map...  Need to consider how to handle it. Must have at least one  miner (use first miner)
}
