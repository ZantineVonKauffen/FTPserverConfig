#!/bin/bash
#Packet Installation
sudo apt -y update
DEBIAN_FRONTEND=noninteractive sudo apt -y upgrade
sudo apt -y install bind9 ftp

#File copying

cp /vagrant/DNS/named /etc/default
cp /vagrant/DNS/named.conf.local /etc/bind
cp /vagrant/DNS/named.conf.options /etc/bind
cp /vagrant/DNS/resolv.conf /etc
cp /vagrant/DNS/sri.ies.dns /var/lib/bind/sri.ies.dns
cp /vagrant/DNS/sri.ies.rev /var/lib/bind/sri.ies.rev

#Service restart
sudo systemctl restart bind9
