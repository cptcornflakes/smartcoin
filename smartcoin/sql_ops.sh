#!/bin/bash

if [[ -n "$HEADER_sql_ops" ]]; then
        return 0
fi
HEADER_sql_ops="included"
SQL_DB=""

RunSQL()
{
        local Q
        Q="$*"
        if [[ -n "$Q" ]]; then
		sqlite3 -noheader -separator "	" "$HOME"/.smartcoin/"$SQL_DB" "$Q;" | Field_Translate
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
                SQL_DB="smartcoin.db"
        fi
}


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

UseDB "smartcoin.db"
