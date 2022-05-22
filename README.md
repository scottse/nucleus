## Nucleus

A script designed to create the configuration files need for the hub and spoke model using Wireguard VPN software.

Usage: The menu has three options to select from: Server, Peer and quick. Each of the options will create one or many configuration files depending on which option that was selected. 

The files will be created in the home directory of the user running
this script.

### Server
The server option creates single Wireguard server configuration
file with the default name of wg0.comf. This option will ask some questions on how the configuration file should be configured. The public/private key will also be created for the server.

>Note: Peer connections will not be added to configuration file, they must be added manually to the file.

### Peer
The peer option creates a single Wireguard peer configuration
file with the filename is selected by the user. This option will ask some on how the file should be configured. The public/private key will also be created for the peer.

>Note: The peer will not added to any server configuration files, they 
must be added manually into the file.

### Quick
The quick option creates a single Wireguard server configuration
file and multiples of peer configuration files. This option will ask some questions on how the server and peer configuration files,
like directory name, DNS IP address and more.

The default server file name is wg0.conf and the peer files
filename default is peerXYZ.conf.

The default IP range is set to 192.168.254.0/24.

The current limit of how many peer files can be created is 253, since 
the first IP address is subnet ID, the second IP address
is used by Wireguard server, and the last IP address is used for broadcasting to the subnet.
