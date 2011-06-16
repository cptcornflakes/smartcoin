#!/bin/bash

. $HOME/smartcoin/smartcoin_ops.sh


AddMenuItem()
{
	menuItem=$(Field_Prepare "$1")
	echo "$menuItem "
}
DisplayMenu()
{	#clear
	#ShowHeader
	fieldArray="$1"

	for item in $fieldArray; do
	num=$(Field 2 "$item")
	listing=$(Field 3 "$item")
	echo -e  "$num) $listing"
	done


}
GetMenuSelection()
{
	fieldArray=$1


	read chosen

	for item in $fieldArray; do
		choice=$(Field 2 "$item")
		if [[ "$chosen" == "$choice" ]]; then
			echo $(Field 1 "$item")
			return 0
		fi
	done
	echo "ERROR"
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
	msg=$1
	clear
	ShowHeader

	echo "Would you like to (A)dd, (E)dit or (D)elete"
	echo $msg"?"
#test
}
GetAEDSelection()
{
	
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
	*)
		echo "ERROR"
		;;	
	esac
}

# Profile Menu
Do_Profile() {
	clear
	ShowHeader

	# Display menu
	M=""
	i=0
	UseDB "smartcoin"
	Q="SELECT * FROM profile where pk_profile>0;"
	R=$(RunSQL "$Q")
	for Row in $R; do
		let i++
		PK=$(Field 1 "$Row")
		profileName=$(Field 2 "$Row")
		M=$M$(AddMenuItem "$PK	$i	$profileName")
	done
	DisplayMenu "$M"

	
	# Process Menu Selection
	PK=$(GetMenuSelection "$M")
	if [[ "$PK" == "ERROR" ]]; then
		DisplayError "Invalid selection!" "5"
		return 0
	fi
	

	# Now load in the profile!
	#get the current profile
	UseDB "smartcoin"
	Q="SELECT value from settings where data=\"current_profile\";"
	R=$(RunSQL "$Q")
	CURRENT_PROFILE=$(Field 1 "$R")

	killMiners $CURRENT_PROFILE
	Q="UPDATE settings set value=$PK where data=\"current_profile\";"
	R=$(RunSQL "$Q")
	

	startMiners $PK
	GotoStatus

}

# Configure Miners Menu
Do_Miners() {
	clear
	ShowHeader
	#Add/Edit/Delete?
	AddEditDelete "miners"
	action=$(GetAEDSelection)
		
	case "$action" in
	ADD)
		Add_Miners
		;;
	DELETE)
		Delete_Miners
		;;

	EDIT)
		Edit_Miners
		;;
	*)
		DisplayError "Invalid selection!" "5"
		;;	

	esac


	
}
Add_Miners()
{
	#table:miner fields:pk_miner, name, launch, path
	clear
	ShowHeader
	echo "ADDING MINER"
	echo "------------"
	echo "Give this miner a nickname"
	read minerName
	echo "Enter the miner's path (i.e. /home/you/miner/)"
	read minerPath
	echo "Enter the miner's launch string"
	echo "Note:use special strings <#user#>, <#path#>, <#server#>"
	echo "<#port#>, and <#device#>"
	echo "i.e.  phoenix.py -v -u http://<#user#>:<#pass#>@<#server#>:<#port#>/ -k phatk device=<#device#> worksize=256 vectors aggression=11 bfi_int fastloop=false"
	read minerLaunch


	echo "Adding Miner..."
	Q="INSERT INTO miner SET name='$minerName', launch='$minerLaunch', path='$minerPath'"
	RunSQL "$Q"


}
Edit_Miners()
{
	clear
	ShowHeader
	echo "SELECT MINER TO EDIT"
	M=""
	i=0
	UseDB "smartcoin"
	Q="SELECT * FROM miner;"
	R=$(RunSQL "$Q")
	for Row in $R; do
		let i++
		PK=$(Field 1 "$Row")
		minerName=$(Field 2 "$Row")
		M=$M$(AddMenuItem "$PK	$i	$minerName")
	done
	DisplayMenu "$M"
	PK=$(GetMenuSelection "$M")
	if [[ "$PK" == "ERROR" ]]; then
		DisplayError "Invalid selection!" "5"
		return 0
	fi
	
	Q="SELECT * FROM miner WHERE pk_miner=$PK;"
	R=$(RunSQL "$Q")
	cname=$(Field 2 "$R")
	claunch=$(Field 3 "$R")
	cpath=$(Field 4 "$R")


	clear
	ShowHeader
	echo "EDITING MINER"
	echo "------------"
	echo "Give this miner a nickname"
	read -e -i "$cname" minerName
	
	echo "Enter the miner's path (i.e. /home/you/miner/)"
	read -e -i "$cpath" minerPath

	echo "Enter the miner's launch string"
	echo "Note:use special strings <#user#>, <#path#>, <#server#>"
	echo "<#port#>, and <#device#>"
	read -e -i "$claunch" minerLaunch



	echo "Updating Miner..."

	Q="UPDATE miner SET name='$minerName', launch='$minerLaunch', path='$minerPath'"
	RunSQL "$Q"

}
Delete_Miners()
{
	clear
	ShowHeader
	echo "SELECT MINER TO DELETE"
	M=""
	i=0
	UseDB "smartcoin"
	Q="SELECT * FROM miner;"
	R=$(RunSQL "$Q")
	for Row in $R; do
		let i++
		PK=$(Field 1 "$Row")
		minerName=$(Field 2 "$Row")
		M=$M$(AddMenuItem "$PK	$i	$minerName")
	done
	DisplayMenu "$M"
	PK=$(GetMenuSelection "$M")
	if [[ "$PK" == "ERROR" ]]; then
		DisplayError "Invalid selection!" "5"
		return 0
	fi
	echo "Deleting Miner..."
	Q="DELETE FROM miner WHERE pk_miner=$PK"
	RunSQL "$Q"
}


# Configure Pools Menu
Do_Pools() {
 echo "Hello"
}





while true
do
	clear
	ShowHeader
	echo "1) Reboot Computer"
	echo "2) Restart smartcoin"
	echo "3) Select Profile"
	echo "4) Configure Miners"
	echo "5) Configure Pools"
	echo "6) Configure Workers"
	echo "7) Configure GPU(s)"
	echo "8) Configure Mappings"
	echo "9) Go To Status screen"
	echo "10) Go To Monitor screen"

	read selection

	case "$selection" in
		1)

			;;
		2)
			;;
		3)
			Do_Profile
			;;
		4)	
			Do_Miners
			;;
		6)
			;;

		7)
			;;
	
		8)

			;;

		9)
		
			;;

		10)

			;;
		*)

			;;
	esac
done






