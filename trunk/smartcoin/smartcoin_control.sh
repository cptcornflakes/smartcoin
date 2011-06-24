#!/bin/bash
# smartcoin_control.sh
# This script handles all of the user configurable options and menu system of smartcoin.
# Only one instance of this control script runs on the local machine, it uses and stores database information
# which lets smartcoin interact with multiple machines.
# This script only handles database interaction, and doesn't launch or kill any other processes directly.


. $HOME/smartcoin/smartcoin_ops.sh



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

	

	UseDB "smartcoin"
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
	local resp="-1"  
	local available

	local _ret=$1
	local msg=$2
	local default=$3
	
	if [[ "$default" == "1" ]]; then
		default="y"
	else
		default="n"
	fi

	echo "$msg"                                             
	until [[ "$resp" != "-1" ]]; do                                         
		read -e -i "$default" available                                                  
		                                                        
		available=`echo $available | tr '[A-Z]' '[a-z]'`                
		if [[ "$available" == "y" ]]; then                              
			resp="1"                                                
		elif [[ "$available" == "n" ]]; then                            
			resp="0"                                                
		else                                                            
			echo "Invalid response!"                                
		fi                                                              
	done    
	eval $_ret="'$resp'"
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

	echo "Would you like to (A)dd, (E)dit or (D)elete"
	echo $msg"?"
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
	*)
		echo "ERROR"
		;;	
	esac
}

# ### END UI HELPER FUNCTIONS ###

# Profile Menu
Do_ChangeProfile() {

	clear
	ShowHeader

	# Add the flags for the dynamically generated profiles
	autoEntry=$(FieldArrayAdd "-2	1	Donation")
	autoEntry=$autoEntry$(FieldArrayAdd "-1	2	Automatic")

	# Display menu
	Q="SELECT pk_machine,name from machine"
	E="Select the machine from the list above that you wish to change the profile on"
	GetPrimaryKeySelection thisMachine "$Q" "$E"

	Q="SELECT pk_profile, name FROM profile where fk_machine=$thisMachine AND pk_profile>0 ORDER BY pk_profile ASC;"
	E="Select the profile from the list above that you wish to switch to"
	GetPrimaryKeySelection thisProfile "$Q" "$E" "" "$autoEntry"
	
	SetCurrentProfile "$thisMachine" "$thisProfile"
	GotoStatus

}
Do_Settings() {
	clear
	ShowHeader

	echo "EDIT SETTINGS"
	Q="SELECT pk_settings, description FROM settings WHERE description !='';"
	E="Select the setting from the list above that you wish to edit"
	GetPrimaryKeySelection thisSetting "$Q" "$E"

	Q="SELECT value, description FROM settings WHERE pk_settings=$thisSetting;"
	R=$(RunSQL "$Q")
	settingValue=$(Field 1 "$R")
	settingDescription=$(Field 2 "$R")
	
	echo "New $settingDescription"
	read -e -i "$settingValue" newSetting

	# sanitize the input a little
	newSetting=${$newSetting#:}

	echo "Updating Setting..."
	Q="UPDATE settings SET value='$newSetting' WHERE pk_settings=$thisSetting;"
	RunSQL "$Q"
	sleep 1
	echo "done."

	
}
Do_AutoProfile() {
	clear
	ShowHeader

	# Display menu
	Q="SELECT pk_machine,name from machine"
	E="Select the machine from the list above that you wish to run the automatic profile on"
	GetPrimaryKeySelection thisMachine "$Q" "$E"

	SetProfile "$thisMachine" "-1"
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
	Q="SELEECT pk_machine, name from machine;"
	E="Please select the machine from the list above that is hosting this miner"
	GetPrimaryKeySelection thisMachine "$Q" "$E"
	echo "Give this miner a nickname"
	read minerName
	echo "Enter the miner's path (i.e. /home/you/miner/)"
	read minerPath
	echo "Enter the miner's launch string"
	echo "Note:use special strings <#user#>, <#path#>, <#server#>"
	echo "<#port#>, and <#device#>"
	echo "i.e.  phoenix.py -v -u http://<#user#>:<#pass#>@<#server#>:<#port#>/ -k phatk device=<#device#> worksize=256 vectors aggression=11 bfi_int fastloop=false"
	read minerLaunch
	E="Do you want this to be the the default miner for this machine?"
	GetYesNoSelection defaultMiner "$E"

	echo "Adding Miner..."
	Q="INSERT INTO miner SET name='$minerName', launch='$minerLaunch', path='$minerPath', fk_machine=$thisMachine"
	RunSQL "$Q"


	Q="SELECT pk_miner FROM miner ORDER BY pk_miner DESC LIMIT 1;"
	R=$(RunSQL "$Q")
	insertedID=$(Field 1 "$R")


	if [[ "$defaultMiner" = "1" ]]; then
		SetDefaultMiner "$thisMachine" "$insertedID"
	fi

	echo "done."
	sleep 1

}
Edit_Miners()
{
	clear
	ShowHeader
	echo "SELECT MINER TO EDIT"
	Q="SELECT pk_machine,name FROM machine;"
	E="Select the machine the miner resides on"
	GetPrimaryKeySelection thisMachine "$Q" "$E"

	Q="SELECT pk_miner, name FROM miner WHERE fk_machine=$thisMachine;"
	E="Select the miner you wish to edit"
	GetPrimaryKeySelection thisMiner "$Q" "$E"

	Q="SELECT name, launch, path, fk_machine, miner_default FROM miner WHERE pk_miner=$thisMiner;"
	R=$(RunSQL "$Q")
	cname=$(Field 1 "$R")
	claunch=$(Field 2 "$R")
	cpath=$(Field 3 "$R")
	cmachine=$(Field 4 "$R")
	cdefault=$(Field 5 "$R")

	if [[ "$cdefault" == "1" ]]; then
		cdefault="y"
	else
		cdefault="n"
	fi

	clear
	ShowHeader
	echo "EDITING MINER"
	echo "------------"

	Q="SELECT pk_machine, name from machine;"                               
	E="Please select the machine from the list above that is hosting this
 miner"                          
	GetPrimaryKeySelection thisMachine "$Q" "$E" "$cmachine"
	echo "Please give this miner a nickname"
	read -e -i "$cname" minerName
	
	echo "Enter the miner's path (i.e. /home/you/miner/)"
	read -e -i "$cpath" minerPath

	echo "Enter the miner's launch string"
	echo "Note:use special strings <#user#>, <#path#>, <#server#>"
	echo "<#port#>, and <#device#>"
	read -e -i "$claunch" minerLaunch

	E="Do you want this to be the the default miner for this machine?"
	GetYesNoSelection defaultMiner "$E" "$cdefault"


	echo "Updating Miner..."

	Q="UPDATE miner SET name='$minerName', launch='$minerLaunch', path='$minerPath', fk_machine=$thisMachine WHERE pk_miner=$thisMiner"
	RunSQL "$Q"

	SetDefaultMiner "$thisMachine" "$thisMiner"
	
	echo "done."
	sleep 1
}
Delete_Miners()
{
	clear
	ShowHeader
	echo "SELECT MINER TO DELETE"

	Q="SELECT pk_machine,name FROM machine;"
	E="Select the machine from the list above that the miner resides on"
	GetPrimaryKeySelection thisMachine "$Q" "$E"
	
	Q="SELECT pk_miner,name FROM miner WHERE fk_machine=$thisMachine;"
	E="Please select the miner from the list above to delete"
	GetPrimaryKeySelection thisMiner "$Q" "$E"

	echo "Deleting Miner..."
	Q="DELETE FROM profile_map WHERE fk_miner=$thisMiner;"
	RunSQL "$Q"

	Q="DELETE FROM miner WHERE pk_miner=$thisMiner"
	RunSQL "$Q"
	echo "done."
	sleep 1
}


# Configure Pools Menu
Do_Pools() {
clear                                                                   
        ShowHeader                                                              
        #Add/Edit/Delete?                                                       
        AddEditDelete "pools"                                                 
        action=$(GetAEDSelection)                                               
                                                                                
        case "$action" in                                                       
        ADD)                                                                    
                Add_Pool                                                     
                ;;                                                              
        DELETE)                                                                 
                Delete_Pool                                                  
                ;;                                                              
                                                                                
        EDIT)                                                                   
                Edit_Pool                                                    
                ;;                                                              
        *)                                                                      
                DisplayError "Invalid selection!" "5"                           
                ;;                                                              
                                                                                
        esac      
}
Add_Pool() 
{
	clear
	ShowHeader
	echo "ADDING POOL"
	echo "-----------"

	echo "Give this pool a nickname"
	read poolName
	echo ""

	echo "Enter the main server address for this pool"
	read  poolServer
	echo ""

	echo "Enter an optional alternate server address for this pool"
	read poolAlternate
	echo ""
        
	echo "Enter the port number to connect to this pool"
	read poolPort
	echo ""
	
	echo "Enter a disconnection timeout for this pool"
	read poolTimeout
	echo ""

        echo "Adding Pool..."

        Q="INSERT INTO pool SET name='$poolName', server='$poolServer', alternateServer='$poolAlternate', port='$poolPort', timeout='$poolTimeout'"
        RunSQL "$Q"
	echo "done."
	sleep 1
}
Edit_Pool()
{
	clear
	ShowHeader
	echo "SELECT POOL TO EDIT"
	Q="SELECT pk_pool, name FROM pool;"
	E="Please select the pool from the list above to edit"
	GetPrimaryKeySelection thisPool "$Q" "$E"
        
	Q="SELECT name,server,alternateServer,port,timeout  FROM pool WHERE pk_pool=$thisPool;"
	R=$(RunSQL "$Q")
	cname=$(Field 1 "$R")
	cserver=$(Field 2 "$R")
	calternate=$(Field 3 "$R")
	cport=$(Field 4 "$R")
	ctimeout=$(FIeld 5 "$R")


	clear
	ShowHeader
	echo "EDITING POOL"
	echo "------------"

	echo "Give this pool a nickname"
	read -e -i "$cname" poolName
	echo ""

	echo "Enter the main server address for this pool"
	read -e -i "$cserver" poolServer
	echo ""

	echo "Enter an optional alternate server address for this pool"
	read -e -i "$calternate" poolAlternate
	echo ""
        
	echo "Enter the port number to connect to this pool"
	read -e -i "$cport" poolPort
	echo ""
	
	echo "Enter a disconnection timeout for this pool"
	read -e -i "$ctimeout" poolTimeout
	echo ""

        echo "Updating Pool..."

        Q="UPDATE pool SET name='$poolName', server='$poolServer', alternateServer='$poolAlternate', port='$poolPort', timeout='$poolTimeout' WHERE pk_pool=$EditPK"
        RunSQL "$Q"
	echo "done."
	sleep 1

}
Delete_Pool()
{
	clear
	ShowHeader
	echo "SELECT POOL TO DELETE"
	Q="SELECT pk_pool,name from pool;"
	E="Please select the pool from the list above to delete"
	GetPrimaryKeySelection thisPool "$Q" "$E"

	echo "Deleting pool..."

	
	# Get a list of the workers that reference the pool...
	Q="SELECT * FROM worker WHERE fk_pool=$thisPool;"
	R=$(RunSQL "$Q")
	for row in $R; do
		thisWorker=$(Field 1 "$row")
	
		# We have to delete all workers that refer to this pool!
		# And delete the profile_map entries that refer to those workers
		Q="DELETE FROM profile_map WHERE fk_worker=$thisWorker;"
		RunSQL "$Q"
	done

	Q="DELETE FROM worker WHERE fk_pool=$thisPool;"
	RunSQL "$Q"
	# And finally, delete the pool!
	Q="DELETE FROM pool WHERE pk_pool=$thisPool;"
	RunSQL "$Q"
	echo "done."
	sleep 1
}



# Configure Workers Menu
Do_Workers() {
        clear
        ShowHeader
        #Add/Edit/Delete?
        AddEditDelete "workers"
        action=$(GetAEDSelection)
                
        case "$action" in
        ADD)
                Add_Workers
                ;;
        DELETE)
                Delete_Workers
                ;;

        EDIT)
                Edit_Workers
                ;;
        *)
                DisplayError "Invalid selection!" "5"
                ;;      

        esac


        
}

Add_Workers()
{
        #table:miner fields:pk_miner, name, launch, path
	clear
        ShowHeader
        echo "ADDING WORKER"
        echo "-------------"
	Q="SELECT pk_pool, name FROM pool;"
	E="What pool listed above is this worker associated with?"
	GetPrimaryKeySelection thisPool "$Q" "$E"

        echo "Give this worker a nickname"
        read -e -i "default" workerName
	echo ""
	

        echo "Enter the username for this worker"
        read userName
	echo ""

        echo "Enter the password for this worker"
        read password
	echo ""

	echo "Enter a priority for this worker"
	echo "Note: this is not yet in use"
	read workerPriority
	echo ""

	E="Would you like this worker to be available to the automatic profile? (y)es or (n)o?"
	GetYesNoSelection workerAllow "$E" 1

	echo "Adding Worker..."
        Q="INSERT INTO worker (fk_pool, name, user, pass, priority, auto_allow, disabled) VALUES ('$thisPool','$workerName,'$userName','$password','$workerPriority','$workerAllow','0');"
        R=$(RunSQL "$Q")
	echo "done."
	sleep 10


}


Edit_Workers()
{
	clear
	ShowHeader
	echo "SELECT WORKER TO EDIT"
	Q="SELECT pk_worker, CONCAT(pool.name,\".\", worker.name) FROM worker LEFT JOIN pool ON worker.fk_pool = pool.pk_pool;"
	E="Please select the worker from the list above to edit"
	GetPrimaryKeySelection EditPK "$Q" "$E"

	Q="SELECT fk_pool,name,user,pass,priority,auto_allow FROM worker WHERE pk_worker=$EditPK;"
	R=$(RunSQL "$Q")
	cpool=$(Field 1 "$R")
	cname=$(Field 2 "$R")
	cuser=$(Field 3 "$R")
	cpass=$(Field 4 "$R")
	cpriority=$(Field 5 "$R")
	callow=$(FIeld 6 "$R")


	clear
	ShowHeader
	echo "EDITING WORKER"
	echo "------------"
	Q="SELECT pk_pool,name FROM pool;"
	E="Which pool does this worker belong to?"
	GetPrimaryKeySelection workerPool "$Q" "$E" "$cpool"
	echo ""

	echo "Give this worker a nickname"
	read -e -i "$cname" workerName
	echo ""

	echo "Enter the user name for this worker"
	read -e -i "$cuser" workerUser
	echo ""

	echo "Enter the password for this worker"
	read -e -i "$cpass" workerPass
	echo ""

	echo "Enter the priority for this worker"
	echo "Note: this is not yet in use"
	read -e -i "$cpriority" workerPriority

	E="Do you want to allow this worker to be added to the automatic profile?"
	GetYesNoSelection workerAllow "$E" "$callow"

	echo "Updating Worker..."

	Q="UPDATE worker SET fk_pool='$workerPool', name='$workerName', user='$workerUser', pass='$workerPass',priority=$workerPriority, auto_allow='$workerAllow' WHERE pk_worker=$EditPK"
	RunSQL "$Q"
	echo "done"
	sleep 1
}



Delete_Workers()
{
	clear
	ShowHeader
	echo "SELECT WORKER TO DELETE"
	Q="SELECT pk_worker, CONCAT(pool.name,\".\", worker.name) FROM worker LEFT JOIN pool ON worker.fk_pool = pool.pk_pool;"
	E="Please select the worker from the list above to delete"
	GetPrimaryKeySelection thisWorker "$Q" "$E"
	

	echo "Deleting Worker..."
	Q="DELETE FROM worker WHERE pk_worker=$PK;"
	RunSQL "$Q"
	# We also have to delete the profile_map entries that refer to this worker!
	Q="DELETE FROM profile_map WHERE fk_worker=$thisWorker;"
	RunSQL "$Q"
	echo "done."
	sleep 1
}


# Configure Profiles Menu
Do_Profile() {
	clear
	ShowHeader
	#Add/Edit/Delete?
	AddEditDelete "profiles"
	action=$(GetAEDSelection)
              
	case "$action" in
	ADD)
		Add_Profile
		;;
	DELETE)
		Delete_Profile
		;;
	EDIT)
		Edit_Profile
		;;
	*)
		DisplayError "Invalid selection!" "5"
		;;      

	esac       
}

Add_Profile()
{
	# Add A Profile
	Q="SELECT pk_machine,name from machine"
	E="Select the machine you wish to add a profile on"
	GetPrimaryKeySelection thisMachine "$Q" "$E"

	echo "Enter a name for this profile"
	read profileName
	echo ""
	Q="INSERT INTO profile set name='$profileName', fk_machine='$thisMachine';"
	R=$(RunSQL "$Q")
		
	Q="SELECT pk_profile FROM profile ORDER BY pk_profile DESC LIMIT 1;"
	R=$(RunSQL "$Q")
	profileID=$(Field 1 "$R")

	# Get the default miner
	Q="SELECT pk_miner, miner_default FROM miner WHERE fk_machine=$thisMachine ORDER BY pk_miner;"
	R=$(RunSQL "$Q")
	selectIndex=0
	for thisRecord in $R; do
		let selectIndex++
		minerDefault=$(Field 2 "$R")
		if [[ "$minerDefalut" == "1" ]]; then
			break
		fi
	done

	Q="Select pk_miner, name from miner WHERE fk_machine=$thisMachine ORDER BY pk_miner;"
	E="Please select the miner from the list above to use with this profile"
	GetPrimaryKeySelection thisMiner "$Q" "$E" "$selectIndex"
	echo ""
	
	instance=0	
	profileProgress=""
	addedInstances=""
	finished=""
	until [[ "$finished" == "1" ]]; do
		let instance++
		clear
		ShowHeader
		profileProgress="Profile: $profileName using device $minerName (adding miner instance #$instance)\n"
		#profileProgress="$profileProgress--------------------------------------------------------------------------------\n"



		echo -e "$profileProgress"
		echo -e "$addedInstances"
		Q="SELECT pk_worker, CONCAT(pool.name,'.', worker.name) FROM worker LEFT JOIN pool ON worker.fk_pool = pool.pk_pool;"
		E="Please select the pool worker from the list above to use with this profile"
		GetPrimaryKeySelection thisWorker "$Q" "$E"
		echo ""
	
	
		Q="SELECT pk_device, name FROM device WHERE disabled=0;"
		E="Please select the device from the list above to use with this profile"
		GetPrimaryKeySelection thisDevice "$Q" "$E"

		
		Q="INSERT INTO profile_map (fk_device,fk_miner,fk_worker,fk_profile) VALUES ($thisDevice,$thisMiner,$thisWorker,$profileID);"
		R=$(RunSQL "$Q")

		clear
		ShowHeader
		Q="SELECT device.name, CONCAT(pool.name,'.',worker.name) FROM profile_map LEFT JOIN device on profile_map.fk_device = device.pk_device LEFT JOIN worker on profile_map.fk_worker = worker.pk_worker LEFT JOIN pool ON worker.fk_pool=pool.pk_pool  WHERE fk_profile = $profileID ORDER BY pk_profile_map ASC;
"
		R=$(RunSQL "$Q")
		addedInstances=""
		for row in $R; do
			addedDevice=$(Field 1 "$row")
			addedWorker=$(Field 2 "$row")
			addedInstances="$addedInstances $addedDevice - $addedWorker\n"
		done
		addedInstances="$addedInstances\n"
		echo -e "$profileProgress"
		echo -e "$addedInstances"
		echo ""
		E="Your current progress on this profile is listed above."
		E="$E Would you like to continue adding instances to this profile? (y)es or (n)o?"
		GetYesNoSelection resp "$E"

		if [[ "$resp" == "0" ]]; then
			finished=1
		fi
	done	
	clear
	ShowHeader
	echo " Your profile is now finished. You can activate it at any time now in the profiles menu."
	sleep 5
}

Edit_Profile()
{
	clear
	ShowHeader
	echo "Editing profiles not yet supported!!! Sorry :("
	sleep 5
	return

	# TODO:  A lot!  Profile editing is pretty difficult!

	#select * from profile_map LEFT JOIN profile on profile_map.fk_profile = profile.pk_profile WHERE profile.fk_machine=1;
	clear
	ShowHeader
	echo "SELECT PROFILE TO EDIT"

	Q="SELECT pk_machine,name from machine"
	E="Select the machine you wish to edit the profile on"
	GetPrimaryKeySelection thisMachine "$Q" "$E"

	Q="SELECT pk_profile, name FROM profile WHERE fk_machine=$thisMachine;"
	E="Please select the profile from the list above to edit"
	GetPrimaryKeySelection thisProfile "$Q" "$E"
	echo ""

	clear
	ShowHeader

	Q="SELECT pk_profile_map, worker.name ,miner.name, device.name FROM profile_map LEFT JOIN worker ON profile_map.fk_worker=worker.pk_worker LEFT JOIN miner ON profile_map.fk_miner=miner.pk_miner LEFT_JOIN device ON profile_map.fk_device=device.pk_device WHERE fk_profile=$thisProfile;"
	R=$(RunSQL "$Q")
	for row in $R; do
		deviceName=$(Field 4 "$row")
		minerName=$(Field 3 "$row")
		workerName=$(Field 2 "$row")
		thisProfileMap=$(Field 1 "$row")

		echo "$deviceName	$workerName"
	done	
	sleep 10
	
}

Delete_Profile()
{
	clear
	ShowHeader
	echo "SELECT PROFILE TO DELETE"
	Q="SELECT pk_machine,name from machine"
	E="Select the machine you wish to delete the profile from"
	GetPrimaryKeySelection thisMachine "$Q" "$E"

	Q="SELECT pk_profile, name FROM profile WHERE fk_machine=$thisMachine;"
	E="Please select the profile from the list above to delete"
	GetPrimaryKeySelection thisProfile "$Q" "$E"

	echo "Deleting profile..."
	# Get a list of the profile_map entries that reference the profile...
	Q="DELETE FROM profile_map WHERE fk_profile=$thisProfile;"

	# And finally, delete the profile!
	Q="DELETE FROM profile WHERE pk_profile=$thisProfile;"
	RunSQL "$Q"
	echo "done."
	sleep 1
}

onfigure Devices Menu
Do_Devices() {
	clear
	ShowHeader
	#Add/Edit/Delete?
	AddEditDelete "devices"
	action=$(GetAEDSelection)
                
	case "$action" in
	ADD)
		Add_Device
		;;
	DELETE)
		Delete_Device
		;;
	EDIT)
		Edit_Device
		;;
	*)
		DisplayError "Invalid selection!" "5"
		;;      
	esac     
}
Add_Device() 
{
	clear
	ShowHeader
	echo "ADDING DEVICE"
	echo "-------------"

	Q="SELECT pk_machine,name from machine"
	E="Select the machine you wish to add the device on"
	GetPrimaryKeySelection thisMachine "$Q" "$E"

	echo "Give this device a nickname"
	read deviceName
	echo ""

	echo "Enter the OpenCL device number"
	read  deviceDevice
	echo ""

	E="Would you like this device to be available to the automatic profile? (y)es or (n)o?"
	GetYesNoSelection deviceAllow "$E" "y"	


	E="Do you want to disable this device?"
	GetYesNoSelection deviceDisabled"$E"
	
	

	
        echo "Adding Device..."

        Q="INSERT INTO device SET name='$deviceName', device='$deviceDevice', disabled='$deviceDisabled', fk_machine=$thisMachine, auto_allow=$deviceAllow"
        RunSQL "$Q"
	#screen -r $sessionName -X wall "Device Added!" #TODO: Get This working!!!
	echo "done."
	sleep 1
}
Edit_Device() 
{
	clear
	ShowHeader
	Q="SELECT pk_machine, name from machine;"                               
	E="Please select the machine from the list above that is hosting this device"                          
	GetPrimaryKeySelection thisMachine "$Q" "$E"

	Q="SELECT pk_device, name FROM device WHERE fk_machine=$thisMachine;"
	E="Please select the device from the list above to edit"
	GetPrimaryKeySelection EditPK "$Q" "$E"
        
	Q="SELECT name,fk_device,auto_allow,disabled FROM device WHERE pk_device=$EditPK;"
	R=$(RunSQL "$Q")
	cname=$(Field 1 "$R")
	cdevice=$(Field 2 "$R")
	callow=$(Field 3 "$R")
	cdisabled=$(Field 4 "$R")
	cmachine=$thisMachine

	clear
	ShowHeader
	echo "EDITING DEVICE"
	echo "--------------"

	Q="SELECT pk_machine,name from machine"
	E="Select the machine for this device"
	GetPrimaryKeySelection thisMachine "$Q" "$E" "$cmachine"

	echo "Give this device a nickname"
	read -e -i "$cname" deviceName
	echo ""

	D=`$HOME/smartcoin/smartcoin_devices.py`
	D=$(Field_Prepare "$D")
	for device in $D; do
		deviceID=$(Field 1 "$device")
		deviceName=$(Field 2 "$device")
		echo "$deviceID) $deviceName"
	done
	echo ""
	echo "Enter the OpenCL device number"
	echo "(The list above is what is detected as available)"
	read  -e -i "$cdevice" deviceDevice
	echo ""

	
	E="Would you like this device to be available to the automatic profile? (y)es or (n)o?"
	GetYesNoSelection deviceAllow "$E" "y" "$callow"

	E="Do you want to disable this device?"
	GetYesNoSelection deviceDisabled "$E" "$cdisabled"
	# TODO: needs auto_allow field!

        echo "Adding Device..."

        Q="UPDATE device SET name='$deviceName', device='$deviceDevice', fk_machine=$thiMachine, disabled='$deviceDisabled', auto_allow=$deviceAllow WHERE pk_device=$EditPK"
        RunSQL "$Q"
	echo done
	sleep 1

}
Delete_Device()
{
	clear
	ShowHeader
	echo "SELECT DEVICE TO DELETE"
	Q="SELECT pk_machine, name from machine;"                               
	E="Please select the machine from the list above that is hosting this device"                          
	GetPrimaryKeySelection thisMachine "$Q" "$E"

	Q="SELECT pk_device, name FROM device WHERE fk_machine=$thisMachine;"
	E="Please select the device from the list above to delete"
	GetPrimaryKeySelection thisDevice "$Q" "$E"

	echo "Deleting device..."


	# Delete entries from the profile profile_map that use this device!
	Q="DELETE from profile_map where fk_device=$thisDevice;"
	RunSQL "$Q"

	# And finally, delete the device!
	Q="DELETE FROM device WHERE pk_device=$thisDevice;"
	RunSQL "$Q"
	echo "done."
	sleep 1
}

while true
do
	clear
	ShowHeader
	echo "1) Reboot Computer"
	echo "2) Kill smartcoin (exit)"
	echo "3) Disconnect from smartcoin (leave running)"
	echo "4) Edit Settings"
	echo "5) Select Profile"
	echo "6) Configure Miners"
	echo "7) Configure Workers"
	echo "8) Configure Profiles"
	echo "9) Configure Devices"
	echo "10) Configure Pools"

	read selection

	case "$selection" in
		1)
			echo "Are you sure you want to reboot? (y)es or (n)o?"
			resp=""
			until [[ "$resp" != "" ]]; do
				read available
			        
				available=`echo $available | tr '[A-Z]' '[a-z]'`
				if [[ "$available" == "y" ]]; then
					resp="1"
				elif [[ "$available" == "n" ]]; then
					resp="0"
				else
					echo "Invalid response!"
		
	
				fi
			done	
			if [[ "$resp" == "1" ]]; then
				echo " Going down for a reboot!"
				sudo reboot
			fi
			;;
		2)
			echo "exit" >$commPipe
			;;
		3)
			echo "detach" >$commPipe
			;;
		4)
			Do_Settings
			;;
		5)
			Do_ChangeProfile
			;;
		6)	
			Do_Miners
			;;
		7)
			Do_Workers
			;;

		8)
			Do_Profile
			;;
	
		9)
			Do_Devices
			;;

		10)
			Do_Pools
			;;
			
		*)

			;;
	esac
done






