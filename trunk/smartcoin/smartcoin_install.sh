#!/bin/bash
CUR_LOCATION="$( cd "$( dirname "$0" )" && pwd )"

. $CUR_LOCATION/smartcoin_ops.sh

#INSTALL_LOCATION=$1

if [[ "$INSTALL_LOCATION" == "" ]]; then
	INSTALL_LOCATION="$CUR_LOCATION"
fi

AMD_SDK_PATH=""


CheckIfAlreadyInstalled() {
	Q="SELECT COUNT(*) FROM settings;"
	R=$(RunSQL "$Q")
	cnt=$(Field 1 "$R")


	if [[ "$cnt" -ge 1 ]]; then
		echo "The installer has already been run before.  You cannot run it again"
		echo "Perhaps you should do a full reinstall, and try again."
		exit
	fi
	
}


findAMDSDK()
{
	local location=`sudo find / -type d -regextype posix-extended -iregex '.*/(AMD|ATI)-(APP|STREAM)-SDK-v[[:digit:].]+-lnx(32|64)/lib/x86(_64)?$'
`
	echo "$location"
}

#################
# BEGIN INSTALLER
#################
Log "==========Beginning Installation============"

clear
CheckIfAlreadyInstalled

Log "Asking user for permission to install"
echo "SmartCoin requires root permissions to install dependencies, create SymLinks and set up the database."
echo "You will be prompted for  your password when needed."
echo "Do you wish to continue? (y/n)"
read getPermission
echo ""

getPermission=`echo $getPermission | tr '[A-Z]' '[a-z]'`
if  [[ "$getPermission" != "y"  ]]; then
	echo "Exiting  SmartCoin installer."
	Log "	Permission Denied."
	exit
fi
Log "	Permission Granted."

# Create .smartcoin directory
Log "Creating .smartcoin directory..." 1
if [[ -d "$HOME/.smartcoin" ]]; then
	mkdir "$HOME/.smartcoin"
fi
echo "done."
echo ""

# Move the database
Log "Creating database in $HOME/.smartcoin/smartcoin.db"
cp $CUR_LOCATION/smartcoin.db $HOME/.smartcoin/smartcoin.db
echo "done."
echo ""

# Create  SymLink
Log "Creating symlink..." 1
sudo ln -s $INSTALL_LOCATION/smartcoin/smartcoin.sh /usr/bin/smartcoin 2> /dev/null
echo "done."
echo ""

# Install dependencies
Log  "Installing dependencies" 1
echo "Please be patient..."
sudo apt-get install -f  -y bc sysstat sqlite3 openssh-server 2> /dev/null
echo "done."
echo ""


# SQL DB calls start now, make sure we set the database
UseDB "smartcoin.db"

# Set up the local machine
Log "Setting up local machine in database..." 1
Q="INSERT INTO machine (name,server,ssh_port,username,auto_allow,disabled) VALUES ('localhost','127.0.0.1',22,'$USER',1,0);"
RunSQL "$Q"
echo "done."


# Populate the database with default pools
Log "Populating database with pool information...."
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('DeepBit','deepbit.net',NULL,8332,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('Bitcoin.cz (slush)','mining.bitcoin.cz',NULL,8332,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('BTCGuild','btcguild.com',NULL,8332,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('BTCMine','btcmine.com',NULL,8332,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('Bitcoins.lc','bitcoins.lc',NULL,8080,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('SwePool','swepool.net',NULL,8337,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('Continuum','continuumpool.com',NULL,8332,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('MineCo','mineco.in',NULL,3000,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('Eligius','mining.eligius.st',NULL,8337,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('CoinMiner','173.0.52.116',NULL,8347,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('ZABitcoin','mine.zabitcoin.co.za',NULL,8332,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('BitClockers','pool.bitclockers.com',NULL,8332,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('MtRed','mtred.com',NULL,8337,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('SimpleCoin','simplecoin.us',NULL,8337,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('Ozco','ozco.in',NULL,8332,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('EclipseMC','us.eclipsemc.com',NULL,8332,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('BitP','pool.bitp.it',NULL,8334,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('BitcoinPool','bitcoinpool.com',NULL,8334,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('EcoCoin','ecocoin.org',NULL,8332,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('BitLottoPool','bitcoinpool.com',NULL,8337,60,1,0);"
R=$(RunSQL "$Q")
Q="INSERT INTO pool (name,server,alternate_server,port,timeout,auto_allow,disabled) VALUES ('X8S','pit.x8s.de',NULL,8337,60,1,0);"                              
R=$(RunSQL "$Q")

# Autodetect cards
echo "Adding available local devices..."
D=`./smartcoin_devices.py`
D=$(Field_Prepare "$D")
for device in $D; do
	id=$(Field 1 "$device")
	devName=$(Field 2 "$device")
	devDisable=$(Field 3 "$device")
	devType=$(Field 4 "$device")

	# TODO: deal with hard coded auto_allow?
	Q="INSERT INTO device (fk_machine,name,device,auto_allow,type,disabled) VALUES (1,'$devName',$id,1,'$devType',$devDisable);"
	RunSQL "$Q"
done
echo "done."
echo ""
echo "These are the locally installed devices that I have found: "
echo "Name	Device #"
echo "----	--------"
Q="SELECT name,device FROM device WHERE disabled=0 ORDER BY device ASC;"
R=$(RunSQL "$Q")
for row in $R; do
	devName=$(Field 1 "$row")
	devID=$(Field 2 "$row")
	echo "$devName	$devID"	
done
echo ""
echo "If these don't look correct, please fix them manually via the controll tab under option 9) Configure Devices."
echo ""

# Autodetect miners
echo "Auto detecting local installed miners..."


#detect phoenix install location
phoenixMiner=`locate phoenix.py | grep -vi svn`
#phoenixMiner=${phoenixMiner%"phoenix.py"}

if [[ "$phoenixMiner" != "" ]]; then
	M=""
	i=0


	for thisLocation in $phoenixMiner; do
		let i++

		M=$M$(FieldArrayAdd "$i	$i	$thisLocation")
	done
	DisplayMenu "$M"

	echo "Select the local phoenix installation from the list above"
	selected="ERROR"
	until [[ "$selected" != "ERROR" ]]; do
		selected=$(GetMenuSelection "$M")
		if [[ "$selected" == "ERROR" ]]; then
			echo "Invalid selection. Please try again."
		fi
	done
	
	i=0
	ret=""
	for thisLocation in $phoenixMiner; do
		let i++
		ret=$thisLocation
		if [[ "$selected" == "$i" ]]; then
			break
		fi
	done

	thisLocation=$thisLocation
	thisLocation=${thisLocation%"phoenix.py"}
	Q="INSERT INTO settings (data,value,description) VALUES ('phoenix_location','$thisLocation','Phoenix installation location');"
	RunSQL "$Q"


	if [[ -d $thisLocation/kernels/phatk ]]; then
		knl="phatk"
	else
		knl="poclbm"
	fi
	Q="INSERT INTO miner (fk_machine, name,launch,path,default_miner,disabled) VALUES (1,'phoenix','python <#path#>phoenix.py -v -u http://<#user#>:<#pass#>@<#server#>:<#port#>/ -k $knl device=<#device#> worksize=128 vectors aggression=11 bfi_int fastloop=false','$thisLocation',0,0);"
	RunSQL "$Q"
fi

# Detect poclbm install location
# TODO: poclbm support needs added!
#poclbmMiner=`locate poclbm.py | grep -vi svn`
#poclbmMiner=${poclbmMiner%"poclbm.py"}
if [[ "$poclbmMiner" != "" ]]; then
	echo "Found poclbm miner installed on local system"
	Q="INSERT INTO miner (fk_machine,name,launch,path,default_miner,disabled) VALUES (1,'poclbm','python poclbm.py -d <#device#> --host <#server#> --port <#port#> --user <#user#> --pass <#pass#> -v -w 128 -f0','$poclbmMiner',0,0);"
	RunSQL "$Q"
fi

# Set the default miner
Q="SELECT pk_miner,name FROM miner ORDER BY pk_miner ASC;"
E="Which miner listed above do you want to be the default miner?"
GetPrimaryKeySelection thisMiner "$Q" "$E"
Q="UPDATE miner SET default_miner='1' WHERE pk_miner=$thisMiner;"
RunSQL "$Q"
Log "Default miner set to $thisMiner"

# Set the current profile! 
# Defaults to Automatic profile until the user gets one set up
Q="DELETE from current_profile WHERE fk_machine=1;"	#A little paranoid, but why not...
RunSQL "$Q"
Q="INSERT INTO current_profile (fk_machine,fk_profile) VALUES (1,-1);"
RunSQL "$Q"
Log "Current profile set to Automatic for localhost"



# Lets see if we can auto-detect the AMD SDK
Log "Asking user if they wish to autodetect the AMD/ATI SDK location."
echo "Smartcoin needs to know the location of the AMD/ATI SDK library in order to work properly."
echo "You can choose to have this location auto-detected, or you can enter it manually."
echo "Note:  Autodetection relies on the linux 'locate' command.  This can take a long time on large file systems."
E="Do you want to attempt to locate the SDK path automatically? (y)es or (n)o?"
GetYesNoSelection autoDetectSDKLocation "$E" "y"

if [[ "$autoDetectSDKLocation" == "1" ]]; then
	Log "	User chose to autodetect"
	sudo updatedb #needed for the linux `locate` command to work reliably
	amd_sdk_location=$(findAMDSDK)
	echo "Please make sure the path below is correct, and change if necessary:"
else
	Log "User chose NOT to autodetect"
	echo "Enter the AMD/ATI SDK path below:"
fi
read -e -i "$amd_sdk_location" location

Q="INSERT INTO settings (data,value,description) VALUES ('AMD_SDK_location','$location','AMD/ATI SDK installation location');"
RunSQL "$Q"
Log "AMD/ATI SDK location set to $location"


# ----------------
# Ask for donation
# ----------------
clear
donation="Please consider donating a small portion of your hashing power to the author of SmartCoin.  A lot of work has gone in to"
donation="$donation making this a good stable platform that will make maintaining your miners much easier, more stable"
donation="$donation and with greater up-time. By donating a small portion"
donation="$donation of your hashing power, you will help to ensure that smartcoin users get support, bugs get fixed and features added."
donation="$donation Donating just 30 minutes a day of your hashing power is only a mall percentage, and will go a long way to show the author of SmartCoin"
donation="$donation your support and appreciation.  You can always turn this setting off in the menu once you feel you've given back a fair amount."
donation="$donation \n\n\n"
donation="$donation I pledge the following minutes per day of my hashing power to the author of smartcoin:"
echo -e $donation
read -e -i "30" myDonation

if [[ "$myDonation" == "" ]]; then
	myDonation=0
fi

Q="INSERT INTO settings (data, value, description) VALUES ('donation_time','$myDonation','Hashpower donation minutes per day');"
RunSQL "$Q"
let startTime_hours=$RANDOM%23
let startTime_minutes=$RANDOM%59
startTime=$startTime_hours$startTime_minutes
Q="INSERT INTO settings (data, value, description) VALUES ('donation_start','$startTime','Time to start hashpower donation each day');"
RunSQL "$Q"
if [[ "$myDonation" -gt "0"  ]]; then
	echo ""
	echo ""
	echo "Thank you for your decision to donate! Your donated hashes will start daily at $startTime_hours:$startTime_minutes for $myDonation minutes."
	echo "You can turn this off at any time from the control screen, and even specify your own start time if you want to."
fi	
echo ""
echo ""

# Set up by default for stable updates!
Log "Setting update system to 'stable'"
Q="INSERT INTO settings (data,value,description) VALUES ('dev_branch','stable','Development branch to follow (stable/experimental)');"
RunSQL "$Q"


# ---------
# Finished!
# ---------
# Tell the user what to do
echo "Installation is now complete.  You can now start SmartCoin at any time by typing the command 'smartcoin' at the terminal."
echo "You will need to go to the control page to set up some workers!"

