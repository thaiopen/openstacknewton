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
ifup enp0s8
ifup enp0s9
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
grep -o '^[^#]*' answerfile.txt
vi /root/answer.txt

sed -i "s/10.0.2.15/192.168.10.10/g

CONFIG_CONTROLLER_HOST=192.168.10.10
CONFIG_COMPUTE_HOSTS=192.168.10.10,192.168.10.11
CONFIG_NETWORK_HOSTS=192.168.10.10
CONFIG_PROVISION_DEMO=n
CONFIG_CEILOMETER_INSTALL=n
CONFIG_HORIZON_SSL=y
CONFIG_NTP_SERVERS=1.th.pool.ntp.org,1.asia.pool.ntp.org
CONFIG_KEYSTONE_ADMIN_PW=password
CONFIG_MARIADB_PW=mypassword1234
CONFIG_NEUTRON_OVS_BRIDGE_MAPPINGS=extnet:br-ex
CONFIG_NEUTRON_OVS_BRIDGE_IFACES=br-ex:enp0s8
CONFIG_NEUTRON_ML2_TYPE_DRIVERS=vxlan,flat
```