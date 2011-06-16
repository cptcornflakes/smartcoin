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

# Tell the user what to do
echo "Installation is complete.  You can now start SmartCoin at any time by typing the command smartcoin at the terminal."
echo "You will need to go to the control page to set up miners, mining devices, pools and workers."

