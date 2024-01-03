# FTP Server configuration  
### By Elias Behar  

The following repository contains a complete FTP Server + DNS server configuration with automatized deployment making usage of Vagrant. This repository contains one Vagrant File written in Ruby with the configuration needed to up two virtual machines with Debian 12 operating system. The repository was created to complete an assignment for Network Services & Internet, in which the following activities had to be completed:  

1. Configure an anonymous FTP Server
     * Allow anonymous connections
     * Set secure access permissions for shared directories
     * Local users not allowed
     * Anonymous users have no write permissions
     * Anonymous users are not asked for a password on login
     * Data connection timeout is 30 seconds
     * Maximum data transfer limitis 5KB/s
     * The server must have a welcoming banner "Welcome to SRI anonymous server"
     * The server shows an ASCII art when in the landing directory
     * Test the connection with passive and active mode

2. Configure a local user FTP Server  
     * Configure the server to authenticate users using operating system accounts. It has two accounts, *charles* and *laura* whose password is *1234*
     * User *charles* is chrooted while *laura* is not
     * Anonymous users are forbidden
     * The server shows a banner saying "Welcome to SRI FTP server"
     * Set access permissions for shared directories for authenticated users
     * Test the configuration with two clients

3. Implement encryption ( SSL/TLS )  
     * Configure the SSL/TLS security layer on the second FTP server
     * Demonstrate the encryption capability during data transfer
     * Verify the correct configuration using testing tools and certificate checks
     * Local users are forced to use secured connections
     * Document the importance of encryption in secure file transfer (at the end of the file)

4. Configure a DNS server
     * Install another virtual machine with authority over the domain *sri.ies*. This machine is called *ns.sri.ies*
     * It has records for *mirror.sri.ies* that points to the anonymous server and *ftp.sri.ies* servers
     * Redirect queries to Cloudfare's server *1.1.1.1*
     * Both FTP servers use *ns.sri.ies*

## Configuration  

I will proceed to describe the configuration at hand.  
There will be two virtual machines using Debian 12 operating system connected to each other via private network, one of them is called *serverFTP* and the other *serverNS*. The first contains the two FTP servers required for this assignment, the second virtual machine is simply the holder for the DNS server and was also used to test the Anonymous server's configuration and functionality.  

Server | Interface | Domain name
--- | --- | ---
serverNS | 192.168.57.10 | ns.sri.ies
serverFTP.Mirror | 192.168.57.20 | mirror.sri.ies
serverFTP.FTP | 192.168.57.30 | ftp.sri.ies

To simplify, serverFTP has two interfaces, each interface is hosting one FTP server, *Mirror* refers to the Anonymous server, while *Ftp* refers to the local user server. The process of hosting multiple instances of FTP servers is complex, but will be explained later on.  
I used Vagrant to create both virtual machines, and used the Vagrant File created after initializing Vagrant to define both computers as  

      Vagrant.configure("2") do |config|
        config.vm.box = "debian/bullseye64"
        config.vm.provider "virtualbox" do |vb|
            vb.memory = "2048" #RAM
            vb.linked_clone =  true
        end
        config.vm.define "serverNS" do |serverNS|
            serverNS.vm.hostname = "ns.sri.ies"
            serverNS.vm.network :private_network, ip: "192.168.57.10"
            serverNS.vm.provision "shell", path: "provNS.sh"
        end
      config.vm.define "serverFTP" do |serverFTP|
          serverFTP.vm.hostname = "sri.ies"
          serverFTP.vm.network :private_network, ip: "192.168.57.20"
          serverFTP.vm.network :private_network, ip: "192.168.57.30"
          serverFTP.vm.provision "shell", path: "provFTP.sh"
      end  
        config.vm.box = "debian/bullseye64"
      end

Both definitions execute a vagrant provision that is written using `shell` which contains a series of commands written in a script to automatize the entire deployment.  
Server NS' provision is dedicated to updating repositories, installing BIND9 DNS services and then copying the configuration files required to startup the server.  
Server FTP's provision is larger, and does the following:  
+ Update repositories
+ Install `vsftpd`, which is the service that will be used to host both servers
+ Copy and paste all configuration files for both instances of `vsftpd`
+ Create users, directories, assign permissions, format documents into Unix
+ Startup the instances of `vsftpd`
+ The provision has a line for creating a new certificate that will be used for encrypting and securing communications with the server. This command cannot be executed automatically as it requires input from the user, therefore, for it to work, after bootup, open a shell and run the command `sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem` to create the certificate. Then run `sudo systemctl restart multihost@ftp` to restart the service, so this way it will work correctly and not return *error* when viewing status

## The Installation  

Multihosting more than one FTP server in one machine is a complicated endeavour using `vsftpd`, but not really. All that is required is to run multiple instances of the daemon. Given I was going to use only one virutal machine to get both FTP servers running, I needed to run two instances of `vsftpd`, so to do this, I first need two configuration files for both instances, and second, to create a duplicate of the process' daemon each running one configuration file. To do this, I prompted the contents of the service's daemon into a .txt file to then open and edit  
The command used was `systemctl cat vsftpd > /vagrant/` , which returns the following:  

    # /lib/systemd/system/vsftpd.service
    [Unit]
    Description=vsftpd FTP server
    After=network.target
    
    [Service]
    Type=simple
    ExecStart=/usr/sbin/vsftpd /etc/vsftpd/%i.conf
    ExecReload=/bin/kill -HUP $MAINPID
    ExecStartPre=-/bin/mkdir -p /var/run/vsftpd/empty
    
    [Install]
    WantedBy=multi-user.target

This is the edited version of the daemon, this is the file assigned to a new process called `multihost@[name]`.  
What does this do? Pay attention to the `%i`.conf at the ExecStart line. This executes the command `/usr/sbin/vsftpd /etc/vsftpd/%i.conf` which is the equivalent to telling the shell to start the service. "%i" refers to whatever name we input after the @ after *multihost*, so this way, if I want to manually initialize the Mirror server, I just need to execute command `systemctl enable --now multihost@mirror`, then the console searches the daemon library searching for multihost@ daemon and then runs the ExecStart using `mirror.conf`, intializing an instance of `vsftpd` service that uses said configuration file. The best part is that this can be done as many times as necessary.  

Now that we know how to run multiple instances of the `vsftpd` service, I mentioned that a configuration file per instance is needed. So in this case, I required two configuration files, *mirror.conf* (for anonymous) and *ftp.conf* (for local users)  
These configuration files *MUST* follow the syntax defined for `vsftpd` which goes by `parameter=option|boolean|value`  
This is Mirror's configuration file and the explanation of each option selected:  

    #Listens only to IPv4 and on the selected address
    listen=YES
    listen_ipv6=NO
    listen_address=192.168.57.20
    
    #Allows anonymous and disables local users
    anonymous_enable=YES
    local_enable=NO
    
    #Path root for anonymous users
    anon_root=/var/mirror/
    
    #Permissions for anon users. They will only be able to get files and cannot put and write
    anon_umask=022
    anon_mkdir_write_enable=NO
    anon_other_write_enable=NO
    anon_world_readable_only=YES
    
    #No password required
    no_anon_password=YES
    
    #Disconnects after 30 seconds afk
    data_connection_timeout=30
    idle_session_timeout=30
    
    #Max rate 5KB
    anon_max_rate=5000
    
    #Banner and ASCII art
    ftpd_banner=Welcome to SRI FTP anonymous server
    dirmessage_enable=YES
    message_file=ascii.message
    dirmessage_enable=YES
    
    #Passive connection options
    pasv_enable=YES
    pasv_min_port=40000
    pasv_max_port=50000

Next is FTP's configuration file, with its explanation for each option selected

    #Listens only to IPv4 and the said address
    listen=YES
    listen_ipv6=NO
    listen_address=192.168.57.30

    #Enables local users and passive connections
    local_enable=YES
    pasv_enable=YES
    pasv_min_port=40000
    pasv_max_port=50000
    
    #No anon users
    anonymous_enable=NO

    #Banner
    ftpd_banner=Welcome to SRI FTP server

    #Enables writting permissions for non chrooted users
    write_enable=YES
    
    #Points path where to send the users for ftp
    local_root=/srv/ftp

    #This configuration indicates all users except those listed in the .chroot_list will be chrooted. This means that if Laura is not to be chrooted, then her name is written in the file vsftpd.chroot_list, because both chroot_local_user and          chroot_list_enable optioons are set to YES
    chroot_local_user=YES
    #This file contains a list of users that will NOT be chrooted in the configuration. Laura is the only user inside this file, therefore, according to the configuration file, she will NOT be chrooted because the list and chrooting are enabled
    chroot_list_file=/etc/vsftpd.chroot_list
    chroot_list_enable=YES

    #This enables the chrooted user to have writing privileges in a folder they are rooted at but they wont be able to delete it nor exit said folder
    allow_writeable_chroot=YES
    
    #SSL/TLS
    #Force secured connections and force logins using encrypted connections, otherwise, connections are all refused
    force_local_data_ssl=YES
    force_local_logins_ssl=YES
    #Disables anonymous ssl connections
    allow_anon_ssl=NO
    
    #Enables SSL
    ssl_enable=YES
    #Paths to the certificate and the private key for connection encryption when connecting to the server. These keys and certificates are defined inmmediatly after booting the computer and are required by the server to run
    rsa_cert_file=/etc/ssl/private/vsftpd.pem
    rsa_private_key_file=/etc/ssl/private/vsftpd.pem
    #Disables old SSL protocols to enable TLS, which is a more modern and updated version for securing communication channels
    ssl_tlsv1=YES
    ssl_sslv2=NO
    ssl_sslv3=NO
    require_ssl_reuse=NO
    #Enables as many ciphers as possible to be used and recognized in encryption, opening up compatibility
    ssl_ciphers=HIGH

As we can see, FTP's configuration file already comes with the SSL/TLS options implemented, because these are defined inside the configuration file. The testing of the server's functioning will be inside the repository's folder, there it can be checked that everything functions as expected.  
Vsftpd servers use Explicit FTPS, which requires a server side certificate stored in a folder with administrative privileges. 

## DNS Server  

To finalize the explanation, the DNS server is very simple. There were no real complex requirements.  
There are 6 files related to this server's configuration, and a shell provision to install BIND9 in the server, and to copy all the configuration files into the machine *serverNS*.  
+ File *named* tells BIND to use IPv4 protocol
+ File *named.conf.options* contains the main configuration options for the server. Only special parameters written are the Forwarded to Cloudfare's server 1.1.1.1 server, the port 53 of address 192.168.67.10 (this server's address) and the allowance of Recursive queries for all hosts inside the network 192.168.57.0/24 and the local host. It also has Dnssec validation enabled
+ File *named.conf.local* where the zone and the reverse zone are defined, with their files saved at /var/lib/bind/sri.ies.dns and /var/lib/bind/sri.ies.rev
+ Files /var/lib/bind/sri.ies.dns and /var/lib/bind/sri.ies.rev which contain the Resource Registries for both zones. Only registries used were NS, A and PTR in these files.
+ Testing of the DNS server's functionality can be seen in the testing .pdf file that contains screenshots of the functioning of the server

## Conclusion

### Why is encryption important in file transfering?  

Frankly speaking, FTP IS an insecure protocol. It was created 40 something years ago and was not conceived to be secure or to have any kind of security measures. All comunications are done in Plain Text, and that includes data transfers and credentials. Therefore, FTP is absolutely vulnerable to Spoofing, Sniffing, Brute Force attacks and many others. For this reason, some security layers were added to FTP, and children protocols were developed, such as SFTPD and FTPS which all use encryption to secure the communications channel and prevent to alteration and manipulatin of information and data flowing in the protocol's channels.  
Considering FTP is a worldwide used protocol used globally in the Internet and the internal networks of companies, organizations and governments, the risks of working with a completely insecure protocol are very big, because anyone would have access to private and secret information protected by law, violating the right to secrecy. To uphold this value of secrecy and privacy, the protocols SFTP and FTPS were created.  
FTPS implements SSL/TLS security for FTP communications channels by making use of hibrid encryption, securing the control and communications channel with assymetric encryption, authenticating the server with an .X509 certificate emitted by a Certification Authority. After securing the connection and validating credentials, the server and user exchange a session private key generated with symmetric encryption whose time to live is for as long as the communication is mantained. This way there are more than two layers of security for the communication channel as a whole, the certificate validates the authenticity of the Server's identity, and the keys keep the running information and credentials secured from eternal influences.  
With this, all the flow of information, files and data that run through the channel are kept on the dark against threaths that want or can hurt the integrity of the organization or the people mantaining the communication.  
In conclusion, encrypting is important for file transfering because the FTP protocol is the most disseminated worldwide, used by almost every single entity and network, but since the protocol is completely unsecure by itself and the data transferred trhough it would be at complete risk of being targetted or altered, encryption methods were introduced to secure the protocol's channels of communication to assertain the integrity of the information and files transfered, the integrity and security of the communications channel and the authenticity of the Servers providing File transfering utilities to clients, reducing the risks to security and privacy for every single person or entity that makes use of this global protocol, which has no other replacement as of now. All other versions of FTP are just security layers added to the protocol itself, which works really well and is improved from time to time. 
