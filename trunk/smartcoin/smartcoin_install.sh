r!/bin/bash

# SmartCoin installer script


. $home/smartcoin/smartcoin_ops.sh

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
sudo apt-get install -y mysql-server open-ssh-server 2> /dev/null
echo "done."
echo ""

# Set up MySQL
echo "Configuring MySQL..."
sudo mysql -A -N -e "CREATE DATABASE smartcoin;" 2> /dev/null
sudo mysql -A -N -e "CREATE USER 'smartcoin'@'localhost'  IDENTIFIED BY 'smartcoin';" 2> /dev/null
sudo mysql -A -N -e "GRANT ALL PRIVILEGES ON smartcoin.* TO 'smartcoin'@'localhost' IDENTIFIED BY 'smartcoin';" 2> /dev/null
echo "done."
echo ""
echo "Importing database schema..."
if [ -f $HOME/smartcoin/smartcoin_schema.sql ]; then
     sudo mysql -A -N -e "source $home/smartcoin/smartcoin_schema.sql;" 2> /dev/null
fi
echo "done."
echo ""

# Populate the database with default pools
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('DeepBit','deepbit.net',NULL,8332,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('Bitcoin.cz (slush)','mining.bitcoin.cz',NULL,8332,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('BTCGuild','btcguild.com',NULL,8332,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('BTCMine','btcmine.com',NULL,8332,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('Bitcoins.lc','bitcoins.lc',NULL,8080,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('SwePool','swepool.net',NULL,8337,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('Continuum','continuumpool.com',NULL,8332,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('MineCo','mineco.in',NULL,3000,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('Eligius','http://mining.eligius.st',NULL,8337,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('CoinMiner','173.0.52.116',NULL,8347,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('ZABitcoin','mine.zabitcoin.co.za',NULL,8332,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('BitClockers','pool.bitclockers.com',NULL,8332,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('MtRed','mtred.com',NULL,8337,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('SimpleCoin','simplecoin.us',NULL,8337,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('Ozco','http://ozco.in',NULL,8332,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('EclipseMC','us.eclipsemc.com',NULL,8332,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('BitP','pool.bitp.it',NULL,8334,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('BitcoinPool','bitcoinpool.com',NULL,8334,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('EcoCoin','ecocoin.org',NULL,8332,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('BitLottoPool','bitcoinpool.com',NULL,8337,60,0);"
RunSQL "$Q"
Q="INSERT INTO pool (name,server,alternateServer,port,timeout,disabled) VALUES ('X8S','pit.x8s.de',8337,60,0);"                              
RunSQL "$Q" 
# Tell the user what to do
echo "Installation is complete.  You can now start SmartCoin at any time by typing the command smartcoin at the terminal."
echo "You will need to go to the control page to set up miners, mining devices, pools and workers."

