# Day 01: Setup Environment
## Install msys64
```
# Setup msys64 
- Download msys64 installer
	- https://msys2.github.io/
	- http://repo.msys2.org/distrib/x86_64/msys2-x86_64-20161025.exe
- install path ``C:\msys64``
```
## Install package and Set PATH in msys2

```
$ pacman -Su
$ pacman -S base-devel
$ pacman -S msys2-devel
$ pacman -S git vim openssh rsync
$ pacman -S mingw-w64-x86_64-toolchain

$ cd /c/msys64/etc/
$ vim profile
export PATH=".:/usr/local/bin:/mingw/bin:/bin:$PATH"
```
## Install Vagrant add add path
```
$ cd /c/msys64/etc/
https://releases.hashicorp.com/vagrant/1.9.1/vagrant_1.9.1.msi
vim profile
#add to last line
export PATH=".:/usr/local/bin:/mingw/bin:/bin:/c/HashiCorp/Vagrant/bin/:$PATH"
```
## Test Vagrant
```
cd ~
mkdir node
cd node
vagrant box add centos/7
vagrant init centos/7
vagrant up
```

## Vagrantfile
```
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"

  config.vm.define :server1 do |node|
     node.vm.network "private_network", ip: "192.168.33.10"
     node.vm.provider :virtualbox do |vb|
	 vb.name = "server1"
	 vb.memory = 4096
	 vb.cpus = 2
     end	
  end
  config.vm.define :server2 do |node|
     node.vm.network "private_network", ip: "192.168.33.11"
     node.vm.provider :virtualbox do |vb|
	 vb.name = "server2"
	 vb.memory = 4096
	 vb.cpus = 2
     end	

  end
end
```
# Test command vagrant
```
# remote
vagrant.exe ssh server1 -c "sudo ifup eth1"
vagrant.exe ssh server2 -c "sudo ifup eth1"

# ssh to server
vagrant.exe ssh server1
sudo su -
passwd

ifup eth1

hostnamectl set-hostname server1.example.com
echo "192.168.33.10 server1.example.com  server1"  >> /etc/hosts
echo "192.168.33.11 server2.example.com  server2" >> /etc/hosts

#gen key
ssh-keygen -t rsa -b 4096

#Fix hardening
vi /etc/ssh/sshd_config    +78

PasswordAuthentication  yes

systemctl restart sshd

#copy key
ssh-copy-id  root@192.168.33.10 
ssh-copy-id  root@192.168.33.10
ss -tulan | grep 22
```
## Vagrant deploy openstack
#### On Controller
```
vagrant.exe ssh controller
sudo su -
ip link
ifup enp0s8     (192.168.10.10)
ifup enp0s9	   (192.168.20.10)
ip a

cat /etc/sysconfig/network-scripts/ifcfg-enp0s8
cat /etc/sysconfig/network-scripts/ifcfg-enp0s9
```
#### On Compute
```
vagrant.exe ssh compute
sudo su - 
ifup eth1
ifup eth2
```
#### on controller
```
ssh-keygen -t rsa
ssh-copy-id root@controller
ssh-copy-id root@compute

ssh root@controller "hostname"
ssh root@compute  "hostname"

chronyc tracking
chronyc sources
ssh root@compute "chronyc tracking"
ssh root@compute "chronyc sources"
```
#### on Controller generate answerfile.txt
```
packstack --gen-answer-file answerfile.txt
cp answerfile.txt answerfile.txt.backup
grep -o '^[^#]*' answerfile.txt  > answerfile.txt.prod

#change ip 
sed -i "s/10.0.2.15/192.168.10.10/g  /root/answer.txt

CONFIG_CONTROLLER_HOST=192.168.10.10
CONFIG_COMPUTE_HOSTS=192.168.10.10,192.168.10.11
CONFIG_NETWORK_HOSTS=192.168.10.10
CONFIG_PROVISION_DEMO=n
CONFIG_CEILOMETER_INSTALL=n
CONFIG_HORIZON_SSL=n
CONFIG_NTP_SERVERS=1.th.pool.ntp.org,1.asia.pool.ntp.org
CONFIG_KEYSTONE_ADMIN_PW=password
CONFIG_MARIADB_PW=mypassword1234
CONFIG_NEUTRON_OVS_BRIDGE_MAPPINGS=extnet:br-ex
CONFIG_NEUTRON_OVS_BRIDGE_IFACES=br-ex:eth1
CONFIG_NEUTRON_ML2_TYPE_DRIVERS=vxlan,flat

packstack --answer-file answerfile.txt.prod

```

## CLI Login
```
cd /root
source  keystonerc_admin
[root@controller ~(keystone_admin)]# openstack user list
+----------------------------------+---------+
| ID                               | Name    |
+----------------------------------+---------+
| 2bf9aad94e634d0189505a25941ffe21 | neutron |
| 646b64e238744c64ae7e68bbf488174e | glance  |
| 8adc886bb9084202a42ed874c6ff0af3 | swift   |
| 99ee223b628341ff9ad3bf66af755a87 | nova    |
| bd1790ac6e8c44e4a467916fba682973 | admin   |
| d0ab666a13b64886bf678f38790b8666 | cinder  |
+----------------------------------+---------+
```
!! Get keystone version3   Project > Compute > Access & Security >  keystone v3

## Add disk Cinder

```
# lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk
├─sda1                    8:1    0    1M  0 part
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part
  ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  /
  └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   20G  0 disk
loop0                     7:0    0    2G  0 loop /srv/node/swiftloopback
loop1                     7:1    0 20.6G  0 loop
[root@controller ~]# ls /dev/lo
log           loop0         loop1         loop-control
```

```
# fdisk /dev/sda 
n
p 
1


w 

```
```
# lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk
├─sda1                    8:1    0    1M  0 part
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part
  ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  /
  └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   20G  0 disk
└─sdb1                    8:17   0   20G  0 part
loop0                     7:0    0    2G  0 loop /srv/node/swiftloopback
loop1                     7:1    0 20.6G  0 loop
[root@controller ~]# pvcreate /dev/sdb1
  Physical volume "/dev/sdb1" successfully created.
[root@controller ~]# vgcreate cinder-volumes /dev/sdb1
  A volume group called cinder-volumes already exists.
  
```
# Add images
```
cd /root
wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
source keystonerc_admin
openstack image list
openstack image create --disk-format qcow2 --container-format bare --public --file ./cirros-0.3.4-x86_64-disk.img cirros

# result
+------------------+------------------------------------------------------+
| Field            | Value                                                |
+------------------+------------------------------------------------------+
| checksum         | ee1eca47dc88f4879d8a229cc70a07c6                     |
| container_format | bare                                                 |
| created_at       | 2017-01-24T09:01:27Z                                 |
| disk_format      | qcow2                                                |
| file             | /v2/images/7383c70b-e7e7-414f-bc51-a451f6b77209/file |
| id               | 7383c70b-e7e7-414f-bc51-a451f6b77209                 |
| min_disk         | 0                                                    |
| min_ram          | 0                                                    |
| name             | cirros                                               |
| owner            | 7082437614104975b878c85bf48bec1f                     |
| protected        | False                                                |
| schema           | /v2/schemas/image                                    |
| size             | 13287936                                             |
| status           | active                                               |
| tags             |                                                      |
| updated_at       | 2017-01-24T09:01:27Z                                 |
| virtual_size     | None                                                 |
| visibility       | public                                               |
+------------------+------------------------------------------------------+

# cd /var/lib/glance/images/
[root@controller images]# ls
7383c70b-e7e7-414f-bc51-a451f6b77209

# openstack image list
+--------------------------------------+--------+--------+
| ID                                   | Name   | Status |
+--------------------------------------+--------+--------+
| 7383c70b-e7e7-414f-bc51-a451f6b77209 | cirros | active |
+--------------------------------------+--------+--------+

```
## Network Namespace
- create router attach to private network
- use ``ip netns exec  <namespace>  bash``
- chmod key permission to 600
- ssh with option -i 
```
ip netns

qrouter-794f2afb-603e-435d-9e6a-5b17b719ffdd
qdhcp-53839b8e-6135-4f8e-bfe8-4951aa223e0c

ip netns exec qrouter-794f2afb-603e-435d-9e6a-5b17b719ffdd bash
ip a
ping 10.0.0.103
chmod 600 key.pem 
ssh  -i key.pem centos@10.0.0.103
```
