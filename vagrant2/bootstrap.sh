#!/bin/bash

#ntp time server
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd

# Set NTP Server
yum install chrony -y
if [ -f /etc/chrony.conf ]; then
    if [ $(hostname -s) = "controller" ]; then
        sed -i.orig '3,6d' /etc/chrony.conf
        sed -i '3i server 1.th.pool.ntp.org iburst' /etc/chrony.conf
        sed -i '4i server 0.asia.pool.ntp.org iburst' /etc/chrony.conf
        sed -i '5i server 2.asia.pool.ntp.org iburst' /etc/chrony.conf
    else
        sed -i.orig '3,6d' /etc/chrony.conf
        sed -i.bak '3i server 192.168.10.10 iburst' /etc/chrony.conf
    fi
fi
sudo systemctl restart chronyd

# Set Repository
yum install -y epel-release
yum install -y https://www.rdoproject.org/repos/rdo-release.rpm
yum update -y
if [ $(hostname -s) = "controller" ]; then
    yum install -y openstack-packstack
fi
yum install -y python-openstackclient
yum install -y openstack-selinux
yum install -y openstack-utils
yum install -y wget tmux vim openssl-devel
