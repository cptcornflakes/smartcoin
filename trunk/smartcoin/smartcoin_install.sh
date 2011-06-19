#!/bin/bash

# SmartCoin installer script


. $HOME/smartcoin/smartcoin_ops.sh

clear

echo "SmartCoin requires root permissions to install dependencies, create SymLinks and set up the database."
echo "You will be prompted for  your password when needed."
echo "Do you wish to continue? (y/n)"
read getPermission
echo ""

getPermission=`echo $getPermission | tr '[A-Z]' '[a-z]'`
if  [[ "$getPermission" != "y"  ]]; then
     echo "Exiting  SmartCoin installer."
     exit
fi


# Create  SymLink
echo "Creating symlink..."
sudo ln -s $HOME/smartcoin/smartcoin.sh /usr/bin/smartcoin 2> /dev/null
echo "done."
echo ""

# Install dependencies
echo  "Installing dependencies, please be patient..."
sudo apt-get install -f  -y systat mysql-server mysql-client open-ssh-server 2> /dev/null
echo "done."
echo ""

# Set up MySQL
UseDB "smartcoin"
echo "Configuring MySQL..."
sudo mysql -A -N -e "CREATE DATABASE smartcoin;" 2> /dev/null
sudo mysql -A -N -e "CREATE USER 'smartcoin'@'localhost'  IDENTIFIED BY 'smartcoin';" 2> /dev/null
sudo mysql -A -N -e "GRANT ALL PRIVILEGES ON smartcoin.* TO 'smartcoin'@'localhost' IDENTIFIED BY 'smartcoin';" 2> /dev/null
echo "done."
echo ""
echo "Importing database schema..."
if [[ -f $HOME/smartcoin/smartcoin_schema.sql ]]; then
     sudo mysql smartcoin < $HOME/smartcoin/smartcoin_schema.sql 2> /dev/null
fi

echo "done."
echo ""

# Populate the database with default pools
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"DeepBit\",\"deepbit.net\",NULL,8332,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"Bitcoin.cz (slush)\",\"mining.bitcoin.cz\",NULL,8332,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"BTCGuild\",\"btcguild.com\",NULL,8332,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"BTCMine\",\"btcmine.com\",NULL,8332,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"Bitcoins.lc\",\"bitcoins.lc\",NULL,8080,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"SwePool\",\"swepool.net\",NULL,8337,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"Continuum\",\"continuumpool.com\",NULL,8332,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"MineCo\",\"mineco.in\",NULL,3000,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"Eligius\",\"i also mining.eligius.st\",NULL,8337,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"CoinMiner\",\"173.0.52.116\",NULL,8347,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"ZABitcoin\",\"mine.zabitcoin.co.za\",NULL,8332,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"BitClockers\",\"pool.bitclockers.com\",NULL,8332,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"MtRed\",\"mtred.com\",NULL,8337,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"SimpleCoin\",\"simplecoin.us\",NULL,8337,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"Ozco\",\"ozco.in\",NULL,8332,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"EclipseMC\",\"us.eclipsemc.com\",NULL,8332,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"BitP\",\"pool.bitp.it\",NULL,8334,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"BitcoinPool\",\"bitcoinpool.com\",NULL,8334,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"EcoCoin\",\"ecocoin.org\",NULL,8332,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"BitLottoPool\",\"bitcoinpool.com\",NULL,8337,60,0);"
R=$(RunSQL "$Q")
Q="INSERT IGNORE INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES (\"X8S\",\"pit.x8s.de\",NULL,8337,60,0);"                              
R=$(RunSQL "$Q")

# Autodetect cards
echo "Adding available devices..."
D=`./smartcoin_devices.py`
D=$(Field_Prepare "$D")
for device in $D; do
	id=$(Field 1 "$device")
	devName=$(Field 2 "$device")
	devDisable=$(Field 3 "$device")

	Q="INSERT IGNORE INTO card (name,device,disabled) VALUES (\"$devName\",$id,$devDisable);"
	R=$(RunSQL "$Q")
done
echo "done."
echo ""

# Autodetect miners
#detect phoenix install location
phoenixMiner=`locate phoenix.py | grep -vi svn`
phoenixMiner=${phoenixMiner%"phoenix.py"}
if [[ "$phoenixMiner" != "" ]]; then
	if [[ -d $HOME/phoenix/kernels/phatk ]]; then
		knl="phatk"
	else
		knl="poclbm"
	fi
	Q="INSERT IGNORE INTO miner (name,launch,path,disabled) VALUES (\"phoenix\",\"phoenix.py -v -u http://<#user#>:<#pass#>@<#server#>:<#port#>/ -k $knl device=<#device#> worksize=128 vectors aggression=11 bfi_int fastloop=false\",\"$phoenixMiner\",0);"
	R=$(RunSQL "$Q")
fi

# Detect poclbm install location
poclbmMiner=`locate poclbm.py | grep -vi svn`
poclbmMiner=${poclbmMiner%"poclbm.py"}
if [[ "$phoenixMiner" != "" ]]; then
	Q="INSERT IGNORE INTO miner (name,launch,path,disabled) VALUES (\"poclbm\",\"poclbm.py -d <#device#> --host <#server#> --port <#port#> --user <#user#> --pass <#pass#> -v -w 128 -f0\",\"$poclbmMiner\",0);"
	R=$(RunSQL "$Q")
fi

Q="INSERT INTO settings SET value=\"-1\", data=\"current_profile\";"
R=$(RunSQL "$Q")


# Tell the user what to do
echo "Installation is complete.  You can now start SmartCoin at any time by typing the command smartcoin at the terminal."
echo "You will need to go to the control page to set up miners, mining devices, pools and workers."

