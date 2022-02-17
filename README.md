# **Описание**

В данном домашнем задании необходимо настроить NFS v3 сервер и проверить его работоспособность, а также примонтировать на клиенте директорию с NFS сервера.

---

# **Подготовка окружения** 

Для тестового стенда нам потребуется Vagrant файл из методички, который создаст две машины - NFS сервер и клиент.
```
# -*- mode: ruby -*-
# vim: set ft=ruby :

Vagrant.configure(2) do |config|
        config.vm.box = "centos/7"
        config.vm.box_version = "2004.01"
        config.vm.provider "virtualbox" do |v|
                v.memory = 256
                v.cpus = 1
        end
        config.vm.define "nfss" do |nfss|
                nfss.vm.network "private_network", ip: "192.168.56.150",
                virtualbox__intnet: "net1"
                nfss.vm.hostname = "nfss"
                nfss.vm.provision "shell", path: "nfss_script.sh"
        end
        config.vm.define "nfsc" do |nfsc|
                nfsc.vm.network "private_network", ip: "192.168.56.151",
                virtualbox__intnet: "net1"
                nfsc.vm.hostname = "nfsc"
                nfsc.vm.provision "shell", path: "nfsc_script.sh"
        end
end
```
А также два скрипта, которые сконфигурят эти машины.

- **nfss_script.sh**
```
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
```

- **nfsc_script.sh**
```
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
```
---

# **Проверка работоспособности NFS**
1. Заходим на сервер и создаём тестовый файл `check_file` в каталоге `/srv/share/upload`.
```
PS D:\TEMP\OTUS\my-hw5> vagrant ssh nfss

[vagrant@nfss ~]$ touch /srv/share/upload/check_file
```
2. Заходим на клиент и проверяем наличие данного файла в `/mnt/upload`, а также создаём обратный тестовый файл `client_file`.
```
PS D:\TEMP\OTUS\my-hw5> vagrant ssh nfsc

[vagrant@nfsc ~]$ ls -la /mnt/upload/
total 0
drwxrwxrwx. 2 nfsnobody nfsnobody 24 Feb 17 23:00 .
drwxr-xr-x. 3 nfsnobody nfsnobody 20 Feb 17 22:36 ..
-rw-rw-r--. 1 vagrant   vagrant    0 Feb 17 23:00 check_file

[vagrant@nfsc ~]$ touch /mnt/upload/client_file
```
3. Перезагружаем клиент.
```
[vagrant@nfsc ~]$ sudo shutdown -r now
Connection to 127.0.0.1 closed by remote host.
Connection to 127.0.0.1 closed.
```
4. После перезагрузки снова заходим, смотрим файлы в директории `/mnt/upload`, убеждаемся что файлы на месте.
```
PS D:\TEMP\OTUS\my-hw5> vagrant ssh nfsc

[vagrant@nfsc ~]$ ls -la /mnt/upload/
total 0
drwxrwxrwx. 2 nfsnobody nfsnobody 43 Feb 17 23:09 .
drwxr-xr-x. 3 nfsnobody nfsnobody 20 Feb 17 22:36 ..
-rw-rw-r--. 1 vagrant   vagrant    0 Feb 17 23:00 check_file
-rw-rw-r--. 1 vagrant   vagrant    0 Feb 17 23:09 client_file
```
5. Перезагружаем сервер.
```
[vagrant@nfss ~]$ sudo shutdown -r now
Connection to 127.0.0.1 closed by remote host.
Connection to 127.0.0.1 closed.
```
6. После перезагрузки подключаемся к серверу и проверяем наличие файлов в директории `/srv/share/upload/`.
```
PS D:\TEMP\OTUS\my-hw5> vagrant ssh nfss
Last login: Thu Feb 17 22:52:06 2022 from 10.0.2.2
[vagrant@nfss ~]$ ls -la /srv/share/upload/
total 0
drwxrwxrwx. 2 nfsnobody nfsnobody 43 Feb 17 23:09 .
drwxr-xr-x. 3 nfsnobody nfsnobody 20 Feb 17 22:36 ..
-rw-rw-r--. 1 vagrant   vagrant    0 Feb 17 23:00 check_file
-rw-rw-r--. 1 vagrant   vagrant    0 Feb 17 23:09 client_file
```
7. Далее делаем проверки NFS, Firewall, Exports, RPC.
```
[vagrant@nfss ~]$ systemctl status nfs
● nfs-server.service - NFS server and services
   Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; enabled; vendor preset: disabled)
  Drop-In: /run/systemd/generator/nfs-server.service.d
           └─order-with-mounts.conf
   Active: active (exited) since Thu 2022-02-17 23:14:48 UTC; 3min 33s ago
  Process: 825 ExecStartPost=/bin/sh -c if systemctl -q is-active gssproxy; then systemctl reload gssproxy ; fi (code=exited, status=0/SUCCESS)
  Process: 802 ExecStart=/usr/sbin/rpc.nfsd $RPCNFSDARGS (code=exited, status=0/SUCCESS)
  Process: 798 ExecStartPre=/usr/sbin/exportfs -r (code=exited, status=0/SUCCESS)
 Main PID: 802 (code=exited, status=0/SUCCESS)
   CGroup: /system.slice/nfs-server.service

[vagrant@nfss ~]$ systemctl status firewalld
● firewalld.service - firewalld - dynamic firewall daemon
   Loaded: loaded (/usr/lib/systemd/system/firewalld.service; enabled; vendor preset: enabled)
   Active: active (running) since Thu 2022-02-17 23:14:44 UTC; 3min 45s ago
     Docs: man:firewalld(1)
 Main PID: 404 (firewalld)
   CGroup: /system.slice/firewalld.service
           └─404 /usr/bin/python2 -Es /usr/sbin/firewalld --nofork --nopid

[vagrant@nfss ~]$ sudo exportfs -s
/srv/share  192.168.56.151/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)

[vagrant@nfss ~]$ showmount -a 192.168.56.150
All mount points on 192.168.56.150:
192.168.56.151:/srv/share
```
8. Аналогично проверяем клиент. 
```
[vagrant@nfsc ~]$ showmount -a 192.168.56.150
All mount points on 192.168.56.150:
192.168.56.151:/srv/share

[vagrant@nfsc ~]$ mount | grep mnt
systemd-1 on /mnt type autofs (rw,relatime,fd=31,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=11087)
192.168.56.150:/srv/share/ on /mnt type nfs (rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,hard,proto=udp,timeo=11,retrans=3,sec=sys,mountaddr=192.168.56.150,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=192.168.56.150)

[vagrant@nfsc ~]$ ls -la /mnt/upload/
total 0
drwxrwxrwx. 2 nfsnobody nfsnobody 43 Feb 17 23:09 .
drwxr-xr-x. 3 nfsnobody nfsnobody 20 Feb 17 22:36 ..
-rw-rw-r--. 1 vagrant   vagrant    0 Feb 17 23:00 check_file
-rw-rw-r--. 1 vagrant   vagrant    0 Feb 17 23:09 client_file

[vagrant@nfsc ~]$ touch /mnt/upload/final_check

[vagrant@nfsc ~]$ ls -la /mnt/upload/
total 0
drwxrwxrwx. 2 nfsnobody nfsnobody 62 Feb 17 23:23 .
drwxr-xr-x. 3 nfsnobody nfsnobody 20 Feb 17 22:36 ..
-rw-rw-r--. 1 vagrant   vagrant    0 Feb 17 23:00 check_file
-rw-rw-r--. 1 vagrant   vagrant    0 Feb 17 23:09 client_file
-rw-rw-r--. 1 vagrant   vagrant    0 Feb 17 23:23 final_check
```

---

# **Заключение**
В данном ДЗ мы расмотрели базовую настройку NFS v3 и команды, с помощью которых можно проверить его работоспособность. 
