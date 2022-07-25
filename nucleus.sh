#!/usr/bin/env bash
#
# Usage: This script is designed to create the server and peer configuration files
# for Wireguard on Linux and MacOS. 
#
# Created by Scott Sewares under the MIT License. More information can be
# found here: https://choosealicense.com/licenses/mit/
# 
# Change log:
# 2022/1/22 - Started work on this script.
# 2022/3/31 - Initial commit.
# 2022/5/22 - Updated name of script.
# 2022/7/24 - Updating file paths for MacOS using Homebrew
#------------------------------------------------------------------------------

# The port Wireguard will use to listen for incoming connections.
LISTEN_PORT=51820

# Set the directory for Wireguard files are stored in. The default directory is
# set to the users home directory.
WG_DIR=~

# This function defines the menu for this script.
function menu() {
  echo
  echo "=============================Nucleus==============================="
  echo "#                                                                 #"
  echo "#      Nucleus is a shell script designed to generate             #"
  echo "#      the configuration files need for either the server/peer    #"
  echo "#      side or both of the Wireguard tunnel.                      #"
  echo "#                                                                 #"
  echo "#      Please select an option below to get started.              #"
  echo "#                                                                 #"
  echo "==================================================================="
  echo
  PS3='Please select an option: '
  options=("Server" "Peer" "Quick" "Help" "Exit")
  select opt in "${options[@]}"; do
    case $opt in
      "Server")
        server ;;
      "Peer")
        peer ;;
      "Quick")
        quick ;;
      "Help")
        help_func ;;
      "Exit")
        echo "Exiting..."
        exit 0
        ;;
      *) echo "Invalid option, please try again." ;;
    esac
  done
}

# This function is used for creating the Wireguard server side configuration file
# and create both private and public keys.
function server() {
  # A set of questions asking the users input on how files should be created.
  echo
  echo "A new directory will be created to store all the files in the home"
  echo "directory of $(echo "$USER")."
  echo
  echo "Let's get started..."
  echo
  echo "What's the name of the directory should we use?"
  while :; do
    read -rp "e.g. foo: " srv_dir
    if [ -d $WG_DIR/"$srv_dir" ]; then
      echo "$srv_dir already exists. Please choose a new directory name."
    else
      break
    fi
  done
  echo "What IP address and CIDR should we use?"
  read -rp "Ex. 192.168.1.1/24 or 10.243.43.1/24: " srv_ip
  echo "Creating the directory for $srv_dir now..."
  mkdir $WG_DIR/"$srv_dir"
  cd $WG_DIR/"$srv_dir"
  umask 077
  echo
  echo "Creating the server private and public key pair..."
  wg genkey | tee $WG_DIR/"$srv_dir"/"$srv_dir".privkey | wg pubkey > $WG_DIR/"$srv_dir"/"$srv_dir".pubkey
  local srv_privkey=$(<$WG_DIR/"$srv_dir"/"$srv_dir".privkey)

  # Creating the server configuration file using the default name of wg0.conf,
  # and the iptables commands can be changed to suit the needs of each
  # of the use cases.
  cat > $WG_DIR/"$srv_dir"/wg0.conf << EOF
[Interface]
Address = $srv_ip
SaveConfig = true
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostUp = ip6tables -A FORWARD -i wg0 -j ACCEPT
PostUp = ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
PostDown = ip6tables -D FORWARD -i wg0 -j ACCEPT
PostDown = ip6tables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
ListenPort = $LISTEN_PORT
PrivateKey = $srv_privkey
EOF

  # Returning back to users home directory.
  echo 
  cd ~
  echo "Returning to menu..."
  # Returning to menu.
  menu
}

# The peer function is for creating the peer configuration file for a existing 
# Wireguar deployments.
function peer() {
  # A set of questions asking the users input on how files should be created.
  echo
  echo "A new directory will be created to store all the files in the home"
  echo "directory of $(echo "$USER")."
  echo
  echo "Let's get started..."
  echo
  echo "What name should be used for the peer conf file?"
  while :; do
    read -rp "e.g. foo (Don't add \".conf\", it will be added later.): " peer_file
    #if [ -d $WG_DIR/$peer_file ] || [[ -e $WG_DIR/$peer_file.privkey && $WG_DIR/$peer_file.pubkey ]]; then
    if [ -e $WG_DIR/"$peer_file"/"$peer_file".conf ]; then
      echo "$peer_file already exists. Please choose a new filename."
    else
      break
    fi
  done
  echo
  echo "What is the peer client's IP address?"
  read -rp "e.g. 10.10.10.10/24: " peer_ip
  echo
  echo "Please provide the Wireguard servers public key"
  read -rp "WG Server Public Key: "  wg_server_pubkey
  echo
  echo "Please provide the Wireguard server IP address or FQDN"
  read -rp "e.g. 10.10.10.10 or vpn.example.com: " wg_endpoint
  echo
  echo "What DNS IP address would you like to use?"
  read -rp "e.g. 1.1.1.1 or 9.9.9.9: " dns_ip
  
  echo "Creating directory for peer conf file..."
  mkdir $WG_DIR/"$peer_file"
  cd $WG_DIR/"$peer_file"
  echo "Creating Wireguard peer key pair..."
  wg genkey | tee $WG_DIR/"$peer_file"/"$peer_file".privkey | wg pubkey >\
  $WG_DIR/"$peer_file"/"$peer_file".pubkey
  
  # Setting the varaibles for the private and public key.
  local peer_priv_key=$(<$WG_DIR/"$peer_file"/"$peer_file".privkey)
  local peer_pub_key=$(<$WG_DIR/"$peer_file"/"$peer_file".pubkey)
  
  # Creating peer confi files.
  cat > $WG_DIR/"$peer_file"/"$peer_file".conf << EOF
[Interface]
Address = $peer_ip
PrivateKey = $peer_priv_key
DNS = $dns_ip

[Peer]
PublicKey = $wg_server_pubkey
Endpoint = $wg_endpoint:$LISTEN_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 30
EOF
  # Returning back to users home directory.
  echo
  cd ~
  echo "Returning to menu..."
  # Returning to menu.
  menu
}

# The quick function is for starting a new Wireguard deployment. It will create
# the server configuration file and a single or multiple peer configuration files.
function quick() {
  # The starting number for the peer configuration files.
  local x=1
  # The start number of the last octet of peer IP address. 
  local y=2
  
  # A set of questions asking the users input on how files should be created.  
  echo
  echo "A new directory will be created to store all the files in the home"
  echo "directory of $(echo "$USER")."
  echo
  echo "Let's get started..."
  echo
  echo "How many peer configuration files should be created?"
  while :; do
    read -rp "e.g. 1 or 10: " num_peer
    if [ "$num_peer" -eq 0 ] || [ "$num_peer" -ge 254 ] ; then
      echo "Interger cannot be 0 or higher than 253. Please try again..."
    else
    break
    fi
  done
  echo "What's name of the directory should be used?"
  while :; do
    read -rp "e.g. foo: " quick_dir
    if [ -d $WG_DIR/"$quick_dir" ]; then
      echo "$quick_dir already exists. Please choose a new directory name."
    else
      break
    fi
  done
  echo
  echo "What's DNS IP address should we use? Leave blank for none."
  read -rp "e.g. 1.1.1.1 or 9.9.9.9: " quick_dns
  echo
  echo "What's the Wireguard endpoint IP address or FQDN we should use?"
  read -rp "e.g. 192.0.2.1 or vpn.example.com: " quick_endpoint
  
  # Creating directory
  umask 077
  mkdir $WG_DIR/"$quick_dir"

  # Creating Wireguard key pairs for server.
  echo "Creating key pair for server"
  wg genkey | tee $WG_DIR/"$quick_dir"/server.privkey | wg pubkey > $WG_DIR/"$quick_dir"/server.pubkey
  local quick_server_pub=$(<$WG_DIR/"$quick_dir"/server.pubkey)
  local quick_server_priv=$(<$WG_DIR/"$quick_dir"/server.privkey)
  echo
  echo "Creating peer and server configuration files(s)..."
  
  # Creating the peer key pair(s) and configuration file(s).
  # need to change with if loop for the max number of pper files.
  while [ $x -le "$num_peer" ]; do
    mkdir $WG_DIR/"$quick_dir"/peer$x
    wg genkey | tee $WG_DIR/"$quick_dir"/peer$x/peer$x.privkey | wg pubkey > $WG_DIR/"$quick_dir"/peer$x/peer$x.pubkey
    quick_peer_priv=$(<$WG_DIR/"$quick_dir"/peer$x/peer$x.privkey)
    quick_peer_pub=$(<$WG_DIR/"$quick_dir"/peer$x/peer$x.pubkey)
    
    # Creating peer conf files.
    cat > $WG_DIR/"$quick_dir"/peer$x/peer$x.conf << EOF
[Interface]
Address = 192.168.254.$y/24
PrivateKey = $quick_peer_priv
DNS = $quick_dns

[Peer]
PublicKey = $quick_server_pub
Endpoint = $quick_endpoint:$LISTEN_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 30
EOF

  # Creating the server configuration file (wg0.conf).
   if [ -e $WG_DIR/"$quick_dir"/wg0.conf ]; then
   cat >> $WG_DIR/"$quick_dir"/wg0.conf << EOF

[Peer]
PublicKey = $quick_peer_pub
AllowedIPs = 192.168.254.$y/32
EOF
  else
    cat > $WG_DIR/"$quick_dir"/wg0.conf << EOF
[Interface]
Address = 192.168.254.1/24
SaveConfig = true
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostUp = ip6tables -A FORWARD -i wg0 -j ACCEPT
PostUp = ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
PostDown = ip6tables -D FORWARD -i wg0 -j ACCEPT
PostDown = ip6tables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
ListenPort = $LISTEN_PORT
PrivateKey = $quick_server_priv

[Peer]
PublicKey = $quick_peer_pub
AllowedIPs = 192.168.254.$y/32
EOF
  fi
  y=$(( $y + 1 ))
  x=$(( $x + 1 ))
  done
  # Returning to menu.
  echo
  echo "Returning to menu..."
  menu
}

# Help section.
function help_func() {
  echo "Usage: The menu has three options to select from: Server, Peer and quick,"
  echo "       Each of the options will create one or many configuration files"
  echo "       depending on which option that was selected."
  echo 
  echo "       The files will be created in the home directory of the user running"
  echo "       this script."
  echo
  echo "       Server: The server option creates single Wireguard server configuration"
  echo "               file with the default name of wg0.comf. This option will ask"
  echo "               some questions on how the configuration file should be configued."
  echo "               The public/private key will also be created for the server."
  echo             
  echo "               Note: Peer connections will not be added to configuration file,"
  echo "                     they must be added manually to the file."
  echo
  echo "        Peer:  The peer option creates a single Wireguard peer configuration"
  echo "               file with the filename is selected by the user. This option will"
  echo "               ask some on how the file should be configured. The public/"
  echo "               private key will also be created for the peer."
  echo 
  echo "               Note: The peer will not added to any server configuration files,"
  echo "                     they must be added manually into the file."
  echo
  echo "       Quick:  The quick option creates a single Wireguard server configuration"
  echo "               file and multiples of peer configuration files. This option will"
  echo "               ask some questions on how the server and peer configuration files,"
  echo "               like directory name, DNS IP address and more."
  echo 
  echo "               The default server file name is wg0.conf and the peer files"    
  echo "               filename default is peerXYZ.conf."
  echo
  echo "               The default IP range is set to 192.168.254.0/24."
  echo
  echo "               The current limit of how many peer files can be created is 253,"
  echo "               since the first IP address is subnet ID, the second IP address"
  echo "               is used by Wireguard server, and the last IP address is used for"
  echo "               broadcasting to the subnet."
  # Returning to menu.
  menu
}

# Checking to see if Wireguard is installed before running the menu function.
# Thix will check for wg on Linux and MacOS.
if [ -e /usr/bin/wg ]; then
  menu
elif [ -e /usr/local/bin/wg ]; then
  menu
elif [ -e /opt/homebrew/bin/wg ]; then  
  menu
else
  echo "Wireguard does not appear to be installed. Please install Wireguard and try again."
  echo
  echo "For Ubuntu/Debian or CentOS/Fedora use the respective commands below:"
  echo "Ubuntu/Debian: sudo apt install wireguard"
  echo "CentOS/Fedora: sudo dnf install wireguard-tools"
  echo "MacOS: Use either Homebrew or Macports to install the Wireguard binaries. Visit the"
  echo "link below for more information."
  echo "Please visit https://www.wireguard.com/install/ for all other distros."
  exit 1
fi
