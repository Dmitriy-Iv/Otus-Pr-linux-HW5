#!/bin/bash

#Install utilities
yum install -y nfs-utils

#Start Firewalld and show status
systemctl enable firewalld --now
systemctl status firewalld

#Make NFS partition mounting permanent
echo "192.168.56.150:/srv/share/ /mnt nfs vers=3,proto=udp,noauto,x-systemd.automount 0 0" >> /etc/fstab

#Reload systemd manager configuration and remount any new entries
systemctl daemon-reload
systemctl restart remote-fs.target

#Check mount 
mount | grep mnt


