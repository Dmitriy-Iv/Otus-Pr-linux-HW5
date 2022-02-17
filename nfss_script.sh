#!/bin/bash

#Install utilities
yum install -y nfs-utils

#Start Firewalld and show status
systemctl enable firewalld --now
systemctl status firewalld

#Add rules to firewall for working nfs3, and rpc-bind services. Check rules 
firewall-cmd --add-service="nfs3" --add-service="rpc-bind" --add-service="mountd" --permanent
firewall-cmd --reload
echo "Allow in Firewall" - $(firewall-cmd --list-all | grep "services" ) | tr a-z A-Z

# Start NFS and check listened ports
systemctl enable nfs --now
ss -tnplu | grep "LISTEN\|UNCONN" | grep '*:2049\|*:20048\|*:111'

#Create shared directory, change owner and rights, check
mkdir -p /srv/share/upload
chown -R nfsnobody:nfsnobody /srv/share
chmod 0777 /srv/share/upload
ls -la /srv/share/

#Add our folder to config file and Reexport all directories, check
cat << EOF > /etc/exports
/srv/share 192.168.56.151/32(rw,sync,root_squash)
EOF
exportfs -r
exportfs -s

