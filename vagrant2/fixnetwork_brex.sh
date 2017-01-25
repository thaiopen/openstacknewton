#!/bin/bash

INF=eth1
mac_eth1=$(cat /sys/class/net/$INF/address)

br_ex=$(cat <<INF
NM_CONTROLLED=no
ONBOOT=yes
IPADDR=192.168.10.10
NETMASK=255.255.255.0
PEERDNS=no
DEVICE=br-ex
NAME=br-ex
DEVICETYPE=ovs
OVSBOOTPROTO=none
TYPE=OVSBridge
HWADDR=$mac_eth1
INF
)

eth=$(cat <<INF
DEVICE=$INF
HWADDR=
TYPE=OVSPort
DEVICETYPE=ovs
OVS_BRIDGE=br-ex
ONBOOT=yes
HWADDR=$mac_eth1
INF
)

echo  "$br_ex" > /etc/sysconfig/network-scripts/ifcfg-br-ex
echo  "$eth" >  /etc/sysconfig/network-scripts/ifcfg-eth1
