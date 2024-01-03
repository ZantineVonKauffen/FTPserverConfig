#!/bin/bash
#Packet insallation
sudo apt -y update
DEBIAN_FRONTEND=noninteractive sudo apt -y upgrade
sudo apt -y install vsftpd dos2unix

#Directory and User setup
#If the following adding of users doesnt work, consider adding them manually. In case it works but passwords are wrong, use:
#sudo passwd laura | charles to change their passwords to 1234 as required
sudo useradd -m -p 1234 laura
sudo useradd -m -p 1234 charles
sudo mkdir /srv/ftp/chrooted
sudo chown charles:charles /srv/ftp/chrooted
sudo chmod 700 /srv/ftp/chrooted
sudo mkdir /etc/vsftpd /var/mirror

#VSFTPD Service Stop

sudo systemctl stop vsftpd
sudo systemctl disable vsftpd

#File copying
sudo cp /vagrant/FTP/resolv.conf /etc
sudo cp /vagrant/Mirror/ascii.message /var/mirror
sudo cp /vagrant/FTP/ftp.conf /etc/vsftpd
sudo cp /vagrant/Mirror/mirror.conf /etc/vsftpd
sudo cp /vagrant/FTP/vsftpd.chroot_list /etc
sudo cp /vagrant/FTP/vsftpd.userlist /etc
sudo cp /vagrant/multihost@.service /lib/systemd/system/

#File formatting
sudo dos2unix /etc/vsftpd/ftp.conf /etc/vsftpd/mirror.conf

#Daemon configuration
#The certificate for securing connections must be created manually because it requires information input. Use the command
#sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem
#After creating the certificate, execute the command
#systemctl restart multihost@ftp 
#To restart the service so it recognizes the certificate's existance
sudo systemctl daemon-reload
sudo systemctl enable --now multihost@ftp
sudo systemctl enable --now multihost@mirror

