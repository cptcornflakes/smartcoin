#!/bin/bash
# smartcoin_control.sh
# This script handles all of the user configurable options and menu system of smartcoin.
# Only one instance of this control script runs on the local machine, it uses and stores database information
# which lets smartcoin interact with multiple machines.
# This script only handles database interaction, and doesn't launch or kill any other processes directly.


. $HOME/smartcoin/smartcoin_ops.sh



# Update system
Do_Update()
{
  local svn_rev=`svn info $HOME/smartcoin/ | grep "^Revision" | awk '{print $2}'`
  clear
  ShowHeader
  E="Your current version is r$svn_rev.\n"
  E=$E"Are you sure that you wish to perform an update?"
	GetYesNoSelection doInstall "$E"

  if [[ "$doInstall" == "0" ]]; then
    return
  fi
  # First, lets update only the update script!
  echo "Bring update script up to current..."
  svn update $HOME/smartcoin/smartcoin_update.sh
  echo ""
  
  Q="SELECT value FROM settings WHERE data='dev_branch';"
  R=$(RunSQL "$Q")
  local branch=$(Field 1 "$R")
  
  branch="stable" # TODO: Remove this once the stable/experimental system is finished and users are up to date!
  
  if [[ "$branch" == "stable" ]]; then
     $HOME/smartcoin/smartcoin_update.sh
  elif [[ "$branch" == "experimental" ]]; then
    $HOME/smartcoin/smartcoin_update.sh 1
  else
    echo ""
    echo "Error! Specified branch must be either \"experimental\" or \"stable\"."
    sleep 5    
  fi

}
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
	
	# Lets see if we can automatically go to the status screen
	Q="SELECT name FROM machine WHERE pk_machine=$thisMachine;"
	R=$(RunSQL "$Q")
	machineName=$(Field 1 "$R")

	screen -r $sessionName -X screen -p 1

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
  EXIT)
    return
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
	Q="SELECT pk_machine, name from machine;"
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
	Q="INSERT INTO miner (name,launch,path,fk_machine) VALUES ('$minerName','$minerLaunch','$minerPath','$thisMachine');"
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


	empty=$(tableIsEmpty "miner" "WHERE fk_machine=$thisMachine")
	if [[ "$empty" ]]; then
		echo ""
		echo "There are no miners to edit."
		sleep 3
		return
	fi

	Q="SELECT pk_miner, name FROM miner WHERE fk_machine=$thisMachine;"
	E="Select the miner you wish to edit"
	GetPrimaryKeySelection thisMiner "$Q" "$E"

	Q="SELECT name, launch, path, fk_machine, default_miner FROM miner WHERE pk_miner=$thisMiner;"
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

	if [[ "$defaultMiner" = "1" ]]; then
		SetDefaultMiner "$thisMachine" "$thisMiner"
	fi
	
	echo "done."
	sleep 1
}
Delete_Miners()
{
	#TODO: deal with situation where we delete the default miner - a new one needs set!
	clear
	ShowHeader
	echo "SELECT MINER TO DELETE"

	Q="SELECT pk_machine,name FROM machine;"
	E="Select the machine from the list above that the miner resides on"
	GetPrimaryKeySelection thisMachine "$Q" "$E"


	empty=$(tableIsEmpty "miner" "WHERE fk_machine=$thisMachine")
	if [[ "$empty" ]]; then
		echo ""
		echo "There are no miners to delete."
		sleep 3
		return
	fi

	
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
        EXIT)
                return
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
  
  # TODO: auto_allow and disabled aren't used yet (if ever?)
  #       fix hard coding once a decision is made

        Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('$poolName','$poolServer','$poolAlternate','$poolPort','$poolTimeout',1,0);"
        RunSQL "$Q"
	echo "done."
	sleep 1
}
Edit_Pool()
{
	clear
	ShowHeader

	empty=$(tableIsEmpty "pool")
	if [[ "$empty" ]]; then
		echo ""
		echo "There are no pools to edit."
		sleep 3
		return
	fi

	echo "SELECT POOL TO EDIT"
	Q="SELECT pk_pool, name FROM pool;"
	E="Please select the pool from the list above to edit"
	GetPrimaryKeySelection thisPool "$Q" "$E"
        
	Q="SELECT name,server,alternate_server,port,timeout  FROM pool WHERE pk_pool=$thisPool;"
	R=$(RunSQL "$Q")
	cname=$(Field 1 "$R")
	cserver=$(Field 2 "$R")
	calternate=$(Field 3 "$R")
	cport=$(Field 4 "$R")
	ctimeout=$(Field 5 "$R")


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

        Q="UPDATE pool SET name='$poolName', server='$poolServer', alternate_server='$poolAlternate', port='$poolPort', timeout='$poolTimeout' WHERE pk_pool=$thisPool"
        RunSQL "$Q"
	echo "done."
	sleep 1

}
Delete_Pool()
{
	clear
	ShowHeader

	empty=$(tableIsEmpty "pool")
	if [[ "$empty" ]]; then
		echo ""
		echo "There are no pools to delete."
		sleep 3
		return
	fi

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
        EXIT)
                return
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
	echo " "

        echo "Give this worker a nickname"
        read -e -i "default" workerName
	echo " "
	

        echo "Enter the username for this worker"
        read userName
	echo " "

        echo "Enter the password for this worker"
        read password
	echo " "

	echo "Enter a priority for this worker"
	echo "Note: this is not yet in use"
	read workerPriority
	echo " "

	E="Would you like this worker to be available to the automatic profile? (y)es or (n)o?"
	GetYesNoSelection workerAllow "$E" 1

	echo "Adding Worker..."
        Q="INSERT INTO worker (fk_pool, name, user, pass, priority, auto_allow, disabled) VALUES ('$thisPool','$workerName','$userName','$password','$workerPriority','$workerAllow','0');"
        R=$(RunSQL "$Q")
	echo "done."
	sleep 1


}


Edit_Workers()
{
	clear
	ShowHeader

	empty=$(tableIsEmpty "worker")
	if [[ "$empty" ]]; then
		echo ""
		echo "There are no workers to edit."
		sleep 3
		return
	fi

	echo "SELECT WORKER TO EDIT"
	Q="SELECT pk_worker, pool.name || '.' || worker.name as fullName FROM worker LEFT JOIN pool ON worker.fk_pool = pool.pk_pool;"
	E="Please select the worker from the list above to edit"
	GetPrimaryKeySelection EditPK "$Q" "$E"

	Q="SELECT fk_pool,name,user,pass,priority,auto_allow FROM worker WHERE pk_worker=$EditPK;"
	R=$(RunSQL "$Q")
	cpool=$(Field 1 "$R")
	cname=$(Field 2 "$R")
	cuser=$(Field 3 "$R")
	cpass=$(Field 4 "$R")
	cpriority=$(Field 5 "$R")
	callow=$(Field 6 "$R")


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

	Q="UPDATE worker SET fk_pool='$workerPool', name='$workerName', user='$workerUser', pass='$workerPass',priority='$workerPriority', auto_allow='$workerAllow' WHERE pk_worker=$EditPK"
	RunSQL "$Q"
	echo "done"
	sleep 1
}



Delete_Workers()
{
	clear
	ShowHeader

	empty=$(tableIsEmpty "worker")
	if [[ "$empty" ]]; then
		echo ""
		echo "There are no workers to delete."
		sleep 3
		return
	fi

	echo "SELECT WORKER TO DELETE"
	Q="SELECT pk_worker, pool.name || '.' || worker.name AS fullName FROM worker LEFT JOIN pool ON worker.fk_pool = pool.pk_pool;"
	E="Please select the worker from the list above to delete"
	GetPrimaryKeySelection thisWorker "$Q" "$E"
	

	echo "Deleting Worker..."
	Q="DELETE FROM worker WHERE pk_worker=$thisWorker;"
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
  EXIT)
    return
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
	Q="INSERT INTO profile (name,fk_machine) VALUES ('$profileName','$thisMachine');"
	R=$(RunSQL "$Q")
		
	Q="SELECT pk_profile FROM profile ORDER BY pk_profile DESC LIMIT 1;"
	R=$(RunSQL "$Q")
	profileID=$(Field 1 "$R")

	# Get the default miner
	Q="SELECT pk_miner, default_miner FROM miner WHERE fk_machine=$thisMachine ORDER BY pk_miner;"
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
	
	Q="SELECT name FROM miner WHERE pk_miner=$thisMiner;"
	R=$(RunSQL "$Q")
	minerName=$(Field 1 "$R")

	instance=0	
	profileProgress=""
	addedInstances=""
	finished=""
	until [[ "$finished" == "1" ]]; do
		let instance++
		clear
		ShowHeader
		profileProgress="Profile: $profileName using miner $minerName (adding miner instance #$instance)\n"
		#profileProgress="$profileProgress--------------------------------------------------------------------------------\n"



		echo -e "$profileProgress"
		echo -e "$addedInstances"
		Q="SELECT pk_worker, pool.name || '.' || worker.name AS fullName FROM worker LEFT JOIN pool ON worker.fk_pool = pool.pk_pool;"
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
		Q="SELECT device.name, pool.name || '.' || worker.name AS fullName FROM profile_map LEFT JOIN device on profile_map.fk_device = device.pk_device LEFT JOIN worker on profile_map.fk_worker = worker.pk_worker LEFT JOIN pool ON worker.fk_pool=pool.pk_pool  WHERE fk_profile = $profileID ORDER BY pk_profile_map ASC;
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
			finished="1"
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
	
	empty=$(tableIsEmpty "profile" "WHERE fk_machine=$thisMachine")
	if [[ "$empty" ]]; then
		echo ""
		echo "There are no profiles to delete."
		sleep 3
		return
	fi

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
  EXIT)
    return
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
	GetYesNoSelection deviceAllow "$E"


	E="Do you want to disable this device?"
	GetYesNoSelection deviceDisabled "$E"
	
	

	
        echo "Adding Device..."
	#TODO: Fix hard coded type
        Q="INSERT INTO device (name,device,disabled,fk_machine,auto_allow,type) VALUES ('$deviceName','$deviceDevice','$deviceDisabled','$thisMachine','$deviceAllow','gpu');"
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

	empty=$(tableIsEmpty "device" "WHERE fk_machine=$thisMachine")
	if [[ "$empty" ]]; then
		echo ""
		echo "There are no devices to edit."
		sleep 3
		return
	fi


	Q="SELECT pk_device, name FROM device WHERE fk_machine=$thisMachine;"
	E="Please select the device from the list above to edit"
	GetPrimaryKeySelection EditPK "$Q" "$E"
        
	Q="SELECT name,device,auto_allow,disabled FROM device WHERE pk_device=$EditPK;"
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
		devID=$(Field 1 "$device")
		devName=$(Field 2 "$device")
		echo "$devID) $devName"
	done
	echo ""
	echo "Enter the OpenCL device number"
	echo "(The list above is what is detected as available)"
	read  -e -i "$cdevice" deviceDevice
	echo ""

	
	E="Would you like this device to be available to the automatic profile? (y)es or (n)o?"
	GetYesNoSelection deviceAllow "$E" "$callow"

	E="Do you want to disable this device?"
	GetYesNoSelection deviceDisabled "$E" "$cdisabled"

        echo "Updating Device..."

	# TODO: fix hard-coded type!
        Q="UPDATE device SET name='$deviceName', device='$deviceDevice', fk_machine='$thisMachine', disabled='$deviceDisabled', auto_allow='$deviceAllow', type='gpu' WHERE pk_device='$EditPK'"
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

	empty=$(tableIsEmpty "device" "WHERE fk_machine=$thisMachine")
	if [[ "$empty" ]]; then
		echo ""
		echo "There are no devices to delete."
		sleep 3
		return
	fi


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
  echo "11) Update Smartcoin"

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
			# Kill the miners
			killMiners
			# Commit suicide
			screen -d -r $sessionName -X quit
			;;
			
		3)
			screen -d $sessionName
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
		 11)
       Do_Update
       ;;
		*)

			;;
	esac
done






