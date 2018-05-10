#!/bin/bash
clear

# The Merit Labs repository on GitHub
GitHubMerit=https://github.com/meritlabs/merit

STRING1="Welcome to the Merit interactive install method."
STRING2="Updating system and installing required packages."
STRING3="Switching to Aptitude"
STRING4="Some optional installs"
STRING5="Starting your Miner"
STRING6="Now, you need to finally start your miner in the following order:"

STRING9=""

# Check if we are root
if [ "$(id -u)" != "0" ]; then
echo "This script must be run as root." 1>&2
exit 1
fi

# First we increase the max number of open files the server can handle
cat >> /etc/sysctl.conf << EOL

fs.file-max = 8192
EOL

sysctl -p

cat >> /etc/security/limits.conf << EOL

* soft     nproc          8192
* hard     nproc          8192
* soft     nofile         8192
* hard     nofile         8192
root soft     nproc          8192
root hard     nproc          8192
root soft     nofile         8192
root hard     nofile         8192
EOL

cat >> /etc/pam.d/common-session << EOL

session required pam_limits.so
EOL

# Install tools for dig and systemctl
echo "Preparing installation..."
apt-get install dnsutils systemd -y > /dev/null 2>&1

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 18.04 LTS?"  >&2; exit 1; }

# CHARS is used for the loading animation further down.
CHARS="/-\|"

# Get the external IP of the VPS
#EXTERNALIP=`dig +short myip.opendns.com @resolver1.opendns.com`
read -e -p "What is the External IP of your VPS? : " EXTERNALIP

clear

echo $STRING1

cat  << EOL

################################# PLEASE READ ################################

You can choose between two installation options: default and advanced.

The advanced installation will install and run the miner under a non-root
user. If you don't know what that means, use the default installation method.

##############################################################################

EOL

sleep 5

read -e -p "Use the Advanced Installation? [N/y] : " ADVANCED

if [[ ("$ADVANCED" == "y" || "$ADVANCED" == "Y") ]]
then
USER=mrtmaster
read -e -p "Password for unprivileged User : " password
adduser $USER --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password > /dev/null
echo $USER:$password | chpasswd > /dev/null
echo "" && echo 'Added user "mrtmaster"' && echo ""
else
USER=root
fi

USERHOME=`eval echo "~$USER"`

sleep 2

clear

read -e -p "Server IP Address: " -i $EXTERNALIP -e IP
#read -e -p "Masternode Private Key ( # THE KEY YOU GENERATED with masternode genkey) : " KEY
read -e -p "Install Fail2ban? [Y/n] : " FAIL2BAN
read -e -p "Install UFW and configure ports? [Y/n] : " UFW

clear

echo $STRING9
echo $STRING2
sleep 10

# Generating Random Passwords
RPCUSER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
RPCPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# Update packages and upgrade Ubuntu
echo "Installing dependencies..."
apt-get -qq update
apt-get -qq upgrade
apt-get -qq autoremove
apt-get -qq install htop
apt-get -qq install build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils python3 &&
apt-get -qq install software-properties-common &&
apt-get -qq update &&
apt-get -qq install virtualenv git unzip pv &&
add-apt-repository -y ppa:bitcoin/bitcoin &&
apt-get -qq install libdb4.8-dev libdb4.8++-dev

sleep 5
clear

echo $STRING3
apt-get -qq install aptitude

echo $STRING4

if [[ ("$FAIL2BAN" == "y" || "$FAIL2BAN" == "Y" || "$FAIL2BAN" == "") ]]; then
aptitude -y install fail2ban
service fail2ban restart
fi

if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
apt-get -qq install ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw limit ssh/tcp
ufw allow 8369/tcp
ufw logging on
yes | ufw enable
ufw status
fi

sleep 5

# Make a 4 Gigabyte swapfile
fallocate -l 4G /swapfile &&
chmod 600 /swapfile
mkswap /swapfile &&
swapon /swapfile &&

# Ensure to use the swapfile after a reboot
cat >> /etc/fstab << EOL
/swapfile none swap sw 0 0
EOL

sleep 3

echo $STRING9
echo "Now we are going to compile the merit binaries"
echo $STRING9

read -p "Compile duration is approximately 40 minutes. Press any key when you are ready to compile. " -n1 -s

echo $STRING9

# Get Merit repository from GitHub
cd $USERHOME
su -c "mkdir $USERHOME/buildmrt" $USER
cd buildmrt
su -c "git clone $GitHubSys" $USER &&
cd merit

# Build Merit Core from sources
su -c "$USERHOME/buildmrt/merit/autogen.sh" $USER &&
su -c "$USERHOME/buildmrt/merit/configure --without-gui" $USER &&
su -c "make -j$(nproc) -pipe" $USER
make install

echo $STRING9
echo "Merit Build completed"
echo $STRING9


read -p "The merit binaries have been compiled. Press any key to proceed... " -n1 -s

echo $STRING9

# Setup Merit core configuration
#su -c "mkdir  $USERHOME/.meritcore" $USER
#su -c "touch $USERHOME/.meritcore/merit.conf" $USER

# Populate merit.conf
cat > "${USERHOME}/Library/Application Support/Merit/merit.conf" << EOL
#
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcallowip=127.0.0.1
#
EOL

# Remove write and read access from other nonpriviliged users
chmod 0600 "${USERHOME}/Library/Application Support/Merit/merit.conf"

clear

echo $STRING5

sleep 3

# Create Meritd Service
cat > /etc/systemd/system/meritd.service << EOL
[Unit]
Description=meritd
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
#ExecStart=/usr/local/bin/meritd -conf=${USERHOME}/.syscoincore/syscoin.conf -datadir=${USERHOME}/.syscoincore  -daemon
#ExecStop=/usr/local/bin/meritd -conf=${USERHOME}/.syscoincore/syscoin.conf -datadir=${USERHOME}/.syscoincore  -daemon stop
ExecStart=/usr/local/bin/meritd -daemon
ExecStop=/usr/local/bin/meritd -daemon stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
EOL

# Enable and start meritd via systemctl
systemctl enable meritd &&
systemctl start meritd

echo "Hold on... "
sleep 60

# Start mining
su -c "/usr/local/bin/merit-cli setmining true" $USER

# Show the meritd status
echo $STRING9
echo $STRING9
su -c "/usr/local/bin/merit-cli getinfo" $USER
