#!/bin/bash
## On Controller
```
yum install -y epel-release
yum install -y https://rdoproject.org/repos/rdo-release.rpm 
yum install -y crudini
yum install -y python-openstackclient
yum install -y openstack-selinux
yum upgrade -y 
```
## Security
create password
```
for i in ROOT_DBPASS ADMIN_PASS CINDER_DBPASS CINDER_PASS DASH_DBPASS  \
DEMO_PASS GLANCE_DBPASS GLANCE_PASS KEYSTONE_DBPASS NEUTRON_DBPASS NEUTRON_PASS \
NOVA_DBPASS NOVA_PASS  RABBIT_PASS; do echo "export $i=$(openssl rand -hex 10)" >> password.txt ;done

cp password.txt password.txt.orig
```
## set ~/.bash_profile
```
vi ~/.bash_profile

source /root/password.txt
echo $ROOT_DBPASS
alias db="mysql -uroot -p$ROOT_DBPASS"
```
## Install mysql 
```
yum install mariadb mariadb-server python2-PyMySQL -y

vi /etc/my.cnf.d/openstack.cnf 
[mysqld]
bind-address = 192.168.10.10

default-storage-engine = innodb
innodb_file_per_table
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
```

```
systemctl start mariadb
systemctl enable mariadb

mysql_secure_installation 
```
## Install rabbitmq
```
yum install epel-release -y
yum install rabbitmq-server -y
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service

rabbitmqctl add_user openstack $RABBIT_PASS
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
```
## Install Memcache
```
yum install memcached python-memcached
systemctl enable memcached.service
systemctl start memcached.service
```
## Create database
```
db -e "CREATE DATABASE keystone;"
db -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';"
db -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';"
db -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'192.168.10.10' IDENTIFIED BY '$KEYSTONE_DBPASS';"
```
## install Apache mod_wsgi
``` 
yum install -y openstack-keystone httpd mod_wsgi -y 

keystonconf=/etc/keystone/keystone.conf
crudini --set $keystonconf database connection mysql+pymysql://keystone:$KEYSTONE_DBPASS@controller/keystone
crudini --set $keystonconf token provider fernet

su -s /bin/sh -c "keystone-manage db_sync" keystone

keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
keystone-manage bootstrap --bootstrap-password $ADMIN_PASS \
  --bootstrap-admin-url http://controller:35357/v3/ \
  --bootstrap-internal-url http://controller:35357/v3/ \
  --bootstrap-public-url http://controller:5000/v3/ \
  --bootstrap-region-id RegionOne
  
```
## config http and wsgi
```
vi /etc/httpd/conf/httpd.conf
ServerName controller

ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/

systemctl enable httpd.service
systemctl start httpd.service
```

## Configure the administrative account
```
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
```

## Create a domain, projects, users, and roles
```

openstack project create --domain default --description "Service Project" service
openstack project create --domain default --description "Demo Project" demo
openstack user create --domain default --password-prompt demo
openstack role create user
openstack role add --project demo --user demo user
```
## verify
```
unset OS_AUTH_URL OS_PASSWORD
openstack --os-auth-url http://controller:35357/v3 \
  --os-project-domain-name Default --os-user-domain-name Default \
  --os-project-name admin --os-username admin token issue
  
```
## Create
```
cat << EOF > admin-openrc
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
```
```
cat << EOF > demo-openrc
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=$DEMO_PASS
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
```

## Install Image on Controller
```
db -e "CREATE DATABASE glance;"
echo $GLANCE_DBPASS

db -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';"
db -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';"
db -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'192.168.10.10' IDENTIFIED BY '$GLANCE_DBPASS';"
```

create glance user
```
openstack user create --domain default --password-prompt glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image

openstack endpoint create --region RegionOne image public http://controller:9292
openstack endpoint create --region RegionOne image internal http://controller:9292
openstack endpoint create --region RegionOne image admin http://controller:9292

```
## install glance service
```
yum install openstack-glance

```
## /etc/glance/glance-api.conf
```
glanceconf=/etc/glance/glance-api.conf 
crudini --set $glanceconf database connection mysql+pymysql://glance:$GLANCE_DBPASS@controller/glance
crudini --set $glanceconf keystone_authtoken auth_uri  http://controller:5000
crudini --set $glanceconf keystone_authtoken auth_url  http://controller:35357
crudini --set $glanceconf keystone_authtoken memcached_servers  controller:11211
crudini --set $glanceconf keystone_authtoken auth_type  password
crudini --set $glanceconf keystone_authtoken project_domain_name  Default
crudini --set $glanceconf keystone_authtoken user_domain_name  Default
crudini --set $glanceconf keystone_authtoken project_name  service
crudini --set $glanceconf keystone_authtoken username  glance
crudini --set $glanceconf keystone_authtoken password  $GLANCE_PASS            
crudini --set $glanceconf paste_deploy flavor  keystone
crudini --set $glanceconf glance_store stores  file,http
crudini --set $glanceconf glance_store default_store  file
crudini --set $glanceconf glance_store filesystem_store_datadir  /var/lib/glance/images/
```

## /etc/glance/glance-registry.conf 
```
glance_registry=/etc/glance/glance-registry.conf
crudini --set $glance_registry database connection  mysql+pymysql://glance:$GLANCE_DBPASS@controller/glance
crudini --set $glance_registry keystone_authtoken auth_uri  http://controller:5000
crudini --set $glance_registry keystone_authtoken auth_url  http://controller:35357
crudini --set $glance_registry keystone_authtoken memcached_servers  controller:11211
crudini --set $glance_registry keystone_authtoken auth_type  password
crudini --set $glance_registry keystone_authtoken project_domain_name  Default
crudini --set $glance_registry keystone_authtoken user_domain_name  Default
crudini --set $glance_registry keystone_authtoken project_name  service
crudini --set $glance_registry keystone_authtoken username  glance
crudini --set $glance_registry keystone_authtoken password  $GLANCE_PASS

crudini --set $glance_registry paste_deploy flavor  keystone
```
```
su -s /bin/sh -c "glance-manage db_sync" glance

systemctl enable openstack-glance-api.service openstack-glance-registry.service
systemctl start openstack-glance-api.service openstack-glance-registry.service

wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img

openstack image create "cirros" \
  --file cirros-0.3.4-x86_64-disk.img \
  --disk-format qcow2 --container-format bare \
  --public
```
--------------------------------------------------
## Nova
db -e "CREATE DATABASE nova_api;"
db -e "CREATE DATABASE nova;"
echo $NOVA_DBPASS
db -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';"
db -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';"
db -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'192.168.10.10' IDENTIFIED BY '$NOVA_DBPASS';"
db -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';"
db -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';"
db -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'192.168.10.10' IDENTIFIED BY '$NOVA_DBPASS';"

openstack user create --domain default \
  --password-prompt nova
  
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute


openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1/%\(tenant_id\)s
openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1/%\(tenant_id\)s
openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1/%\(tenant_id\)s

yum install openstack-nova-api openstack-nova-conductor \
  openstack-nova-console openstack-nova-novncproxy \
  openstack-nova-scheduler

# Install and configure components

novaconf=/etc/nova/nova.conf 

crudini --set $novaconf DEFAULT  enabled_apis  osapi_compute,metadata
crudini --set $novaconf api_database connection  mysql+pymysql://nova:$NOVA_DBPASS@controller/nova_api
crudini --set $novaconf database connection mysql+pymysql://nova:$NOVA_DBPASS@controller/nova


crudini --set $novaconf DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@controller
crudini --set $novaconf DEFAULT auth_strategy keystone
crudini --set $novaconf keystone_authtoken auth_uri http://controller:5000
crudini --set $novaconf keystone_authtoken auth_url  http://controller:35357
crudini --set $novaconf keystone_authtoken memcached_servers controller:11211
crudini --set $novaconf keystone_authtoken auth_type password
crudini --set $novaconf keystone_authtoken project_domain_name Default
crudini --set $novaconf keystone_authtoken user_domain_name Default
crudini --set $novaconf keystone_authtoken project_name  service
crudini --set $novaconf keystone_authtoken username nova
crudini --set $novaconf keystone_authtoken password $NOVA_PASS


crudini --set $novaconf DEFAULT my_ip 192.168.10.10
crudini --set $novaconf DEFAULT use_neutron  True
crudini --set $novaconf firewall_driver nova.virt.firewall.NoopFirewallDriver

crudini --set $novaconf vnc vncserver_listen \$my_ip
crudini --set $novaconf vnc vncserver_proxyclient_address \$my_ip

crudini --set $novaconf  glance api_servers http://controller:9292
crudini --set $novaconf lock_path  /var/lib/nova/tmp

su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage db sync" nova

systemctl enable openstack-nova-api.service \
  openstack-nova-consoleauth.service openstack-nova-scheduler.service \
  openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl start openstack-nova-api.service \
  openstack-nova-consoleauth.service openstack-nova-scheduler.service \
  openstack-nova-conductor.service openstack-nova-novncproxy.service


----------------------------------------
  
#nova compute on computenode 

yum install openstack-nova-compute
echo $RABBIT_PASS
novaconf=/etc/nova/nova.conf 
crudini --set $novaconf DEFAULT enabled_apis osapi_compute,metadata
crudini --set $novaconf DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@controller

crudini --set $novaconf DEFAULT auth_strategy keystone
crudini --set $novaconf keystone_authtoken auth_uri http://controller:5000
crudini --set $novaconf keystone_authtoken auth_url  http://controller:35357
crudini --set $novaconf keystone_authtoken memcached_servers controller:11211
crudini --set $novaconf keystone_authtoken auth_type password
crudini --set $novaconf keystone_authtoken project_domain_name Default
crudini --set $novaconf keystone_authtoken user_domain_name Default
crudini --set $novaconf keystone_authtoken project_name  service
crudini --set $novaconf keystone_authtoken username nova
crudini --set $novaconf keystone_authtoken password $NOVA_PASS
crudini --set $novaconf DEFAULT my_ip 192.168.10.12
crudini --set $novaconf DEFAULT use_neutron  True
crudini --set $novaconf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver 

crudini --set $novaconf vnc enabled  True
crudini --set $novaconf vnc vncserver_listen 0.0.0.0
crudini --set $novaconf vnc vncserver_proxyclient_address \$my_ip
crudini --set $novaconf vnc novncproxy_base_url  http://controller:6080/vnc_auto.html
crudini --set $novaconf glance api_servers  http://controller:9292
crudini --set $novaconf glance oslo_concurrency lock_path /var/lib/nova/tmp
crudini --set $novaconf libvirt virt_type  qemu

crudini --set $novaconf DEFAULT transport_url  rabbit://openstack:$RABBIT_PASS@controller

systemctl enable libvirtd.service openstack-nova-compute.service


91e05d15281] AMQP server on 127.0.0.1:5672 is unreachable: [Errno 111] ECONNREFUSED.
 Trying again in 32 seconds. Client port: None
 
------------------------------------------------------------------------------- 
# Install Networknode on Networknode
### Create neutron user in database

```
db -e "CREATE DATABASE neutron;"
db -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS';"
db -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS';"
source admin_openrc
openstack user create --domain default --password-prompt neutron

openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network

openstack endpoint create --region RegionOne network public http://controller:9696
openstack endpoint create --region RegionOne network internal http://controller:9696
openstack endpoint create --region RegionOne network admin http://controller:9696

##Networking Option 1: Provider networks
On Networknode  controller
```
yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge ebtables
echo $NEUTRON_DBPASS
neutronconf=/etc/neutron/neutron.conf
crudini --set $neutronconf database connection mysql+pymysql://neutron:$NEUTRON_DBPASS@controller/neutron  
crudini --set $neutronconf DEFAULT core_plugin ml2 core_plugin ml2
crudini --set $neutronconf DEFAULT core_plugin ml2 service_plugins 
crudini --set $neutronconf DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@controller
crudini --set $neutronconf DEFAULT auth_strategy keystone
crudini --set $neutronconf keystone_authtoken auth_uri http://controller:5000
crudini --set $neutronconf keystone_authtoken auth_url  http://controller:35357
crudini --set $neutronconf keystone_authtoken memcached_servers controller:11211
crudini --set $neutronconf keystone_authtoken auth_type password
crudini --set $neutronconf keystone_authtoken project_domain_name Default
crudini --set $neutronconf keystone_authtoken user_domain_name Default
crudini --set $neutronconf keystone_authtoken project_name  service
crudini --set $neutronconf keystone_authtoken username neutron
crudini --set $neutronconf keystone_authtoken password $NEUTRON_PASS


crudini --set $neutronconf DEFAULT notify_nova_on_port_status_changes True
crudini --set $neutronconf DEFAULT notify_nova_on_port_data_changes True

crudini --set $neutronconf nova auth_url  http://controller:35357
crudini --set $neutronconf nova auth_type  password
crudini --set $neutronconf nova project_domain_name  Default
crudini --set $neutronconf nova user_domain_name  Default
crudini --set $neutronconf nova region_name  RegionOne
crudini --set $neutronconf nova project_name  service
crudini --set $neutronconf nova username  nova
crudini --set $neutronconf nova password  $NOVA_PASS

crudini --set $neutronconf oslo_concurrency lock_path /var/lib/neutron/tmp
```

## Configure the Modular Layer 2 (ML2) plug-in
```
cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.orig
ml2conf=/etc/neutron/plugins/ml2/ml2_conf.ini
crudini --set $ml2conf ml2 type_drivers flat,vlan
crudini --set $ml2conf ml2 tenant_network_types 
crudini --set $ml2conf ml2 mechanism_drivers linuxbridge
crudini --set $ml2conf ml2 extension_drivers port_security
crudini --set $ml2conf ml2_type_flat flat_networks provider
crudini --set $ml2conf securitygroup enable_ipset  True
```
## Configure the Linux bridge agent
``` 
cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.orig
bridgeconf=/etc/neutron/plugins/ml2/linuxbridge_agent.ini
crudini --set $bridgeconf linux_bridge physical_interface_mappings provider:eth2
crudini --set $bridgeconf vxlan enable_vxlan False
crudini --set $bridgeconf securitygroup enable_security_group  True
crudini --set $bridgeconf securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
```
## Configure the DHCP agent
```
cp /etc/neutron/dhcp_agent.ini  /etc/neutron/dhcp_agent.ini.orig
dhcpconf=/etc/neutron/dhcp_agent.ini 
crudini --set $dhcpconf DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
crudini --set $dhcpconf DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
crudini --set $dhcpconf DEFAULT enable_isolated_metadata True
```

## Configure the metadata agent
```
cp /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini.orig
metaconf=/etc/neutron/metadata_agent.ini 
crudini --set $metaconf DEFAULT nova_metadata_ip  controller
crudini --set $metaconf DEFAULT metadata_proxy_shared_secret  $METADATA_SECRET
```

## Configure the Compute service to use the Networking service
```
cp  /etc/nova/nova.conf /etc/nova/nova.conf.orig
novaconf=/etc/nova/nova.conf 
crudini --set $novaconf neutron url  http://controller:9696
crudini --set $novaconf neutron auth_url  http://controller:35357
crudini --set $novaconf neutron auth_type  password
crudini --set $novaconf neutron project_domain_name  Default
crudini --set $novaconf neutron user_domain_name  Default
crudini --set $novaconf neutron region_name  RegionOne
crudini --set $novaconf neutron project_name  service
crudini --set $novaconf neutron username  neutron
crudini --set $novaconf neutron password  $NEUTRON_PASS
crudini --set $novaconf neutron service_metadata_proxy  True
crudini --set $novaconf neutron metadata_proxy_shared_secret $METADATA_SECRET
## Finalize installation
```
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
systemctl restart openstack-nova-api.service
```

## option1
```
systemctl enable neutron-server.service \
  neutron-linuxbridge-agent.service neutron-dhcp-agent.service \
  neutron-metadata-agent.service
systemctl start neutron-server.service \
  neutron-linuxbridge-agent.service neutron-dhcp-agent.service \
  neutron-metadata-agent.service

 
```
## Install and configure compute node
The compute node handles connectivity and security groups for instances.
config compute node
```
yum install openstack-neutron-linuxbridge ebtables ipset
cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.orig

neutronconf=/etc/neutron/neutron.conf
crudini --set $neutronconf DEFAULT transport_url  rabbit://openstack:$RABBIT_PASS@controller
crudini --set $neutronconf DEFAULT auth_strategy keystone
crudini --set $neutronconf keystone_authtoken auth_uri  http://controller:5000
crudini --set $neutronconf keystone_authtoken auth_url  http://controller:35357
crudini --set $neutronconf keystone_authtoken memcached_servers  controller:11211
crudini --set $neutronconf keystone_authtoken auth_type  password
crudini --set $neutronconf keystone_authtoken project_domain_name  Default
crudini --set $neutronconf keystone_authtoken user_domain_name  Default
crudini --set $neutronconf keystone_authtoken project_name  service
crudini --set $neutronconf keystone_authtoken username  neutron
crudini --set $neutronconf keystone_authtoken password  $NEUTRON_PASS
crudini --set $neutronconf oslo_concurrency lock_path /var/lib/neutron/tmp
```
## Networking Option 1: Provider networks
```
cp  /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.orig
bridgeconf=/etc/neutron/plugins/ml2/linuxbridge_agent.ini 
crudini --set $bridgeconf linux_bridge physical_interface_mappings provider:eth2
crudini --set $bridgeconf vxlan enable_vxlan False
crudini --set $bridgeconf securitygroup enable_security_group True 
crudini --set $bridgeconf securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
```
## Configure the Compute service to use the Networking service
```
cp /etc/nova/nova.conf /etc/nova/nova.conf.orig
novaconf=/etc/nova/nova.conf
crudini --set $novaconf neutron url  http://controller:9696
crudini --set $novaconf neutron auth_url  http://controller:35357
crudini --set $novaconf neutron auth_type  password
crudini --set $novaconf neutron project_domain_name  Default
crudini --set $novaconf neutron user_domain_name  Default
crudini --set $novaconf neutron region_name  RegionOne
crudini --set $novaconf neutron project_name  service
crudini --set $novaconf neutron username  neutron
crudini --set $novaconf neutron password  $NEUTRON_PASS
```

```
systemctl restart openstack-nova-compute.service

systemctl enable neutron-linuxbridge-agent.service
systemctl start neutron-linuxbridge-agent.service

systemctl status neutron-linuxbridge-agent.service
systemctl status openstack-nova-compute.service 
```

## verify from controler
```
. admin-openrc

]# neutron ext-list
+---------------------------+---------------------------------+
| alias                     | name                            |
+---------------------------+---------------------------------+
| default-subnetpools       | Default Subnetpools             |
| availability_zone         | Availability Zone               |
| network_availability_zone | Network Availability Zone       |
| binding                   | Port Binding                    |
| agent                     | agent                           |
| subnet_allocation         | Subnet Allocation               |
| dhcp_agent_scheduler      | DHCP Agent Scheduler            |
| tag                       | Tag support                     |
| external-net              | Neutron external network        |
| flavors                   | Neutron Service Flavors         |
| net-mtu                   | Network MTU                     |
| network-ip-availability   | Network IP Availability         |
| quotas                    | Quota management support        |
| provider                  | Provider Network                |
| multi-provider            | Multi Provider Network          |
| address-scope             | Address scope                   |
| subnet-service-types      | Subnet service types            |
| standard-attr-timestamp   | Resource timestamps             |
| service-type              | Neutron Service Type Management |
| extra_dhcp_opt            | Neutron Extra DHCP opts         |
| standard-attr-revisions   | Resource revision numbers       |
| pagination                | Pagination support              |
| sorting                   | Sorting support                 |
| security-group            | security-group                  |
| rbac-policies             | RBAC Policies                   |
| standard-attr-description | standard-attr-description       |
| port-security             | Port Security                   |
| allowed-address-pairs     | Allowed Address Pairs           |
| project-id                | project_id field enabled        |
+---------------------------+---------------------------------+

```

## Dashboard
```
yum install openstack-dashboard
cp /etc/openstack-dashboard/local_settings /etc/openstack-dashboard/local_settings.orig 
vi /etc/openstack-dashboard/local_settings
```

```
OPENSTACK_HOST = "controller"
ALLOWED_HOSTS = ['*', ]

SESSION_ENGINE = 'django.contrib.sessions.backends.cache'

CACHES = {
    'default': {
         'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
         'LOCATION': '127.0.0.1:11211',
    }
}

OPENSTACK_KEYSTONE_URL = "http://%s:5000/v3" % OPENSTACK_HOST
OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True

OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 2,
}

OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "default"
OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"

OPENSTACK_NEUTRON_NETWORK = {
    'enable_router': False,
    'enable_quotas': False,
    'enable_distributed_router': False,
    'enable_ha_router': False,
    'enable_lb': False,
    'enable_firewall': False,
    'enable_vpn': False,
    'enable_fip_topology_check': False,
}


TIME_ZONE = "Asia/Bangkok"

```

```
CACHES = {
    'default': {
         'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
         'LOCATION': 'controller:11211',
    }
}

[Thu Jan 26 12:06:54.364041 2017] [:error] [pid 2987]     "Unable to create a new session key. "
[Thu Jan 26 12:06:54.364042 2017] [:error] [pid 2987] RuntimeError: Unable to create a new session key. It is likely that the cache is unavailable.

```

vim /etc/sysconfig/memcached
systemctl restart httpd.service memcached.service

export ADMIN_PASS=b10bf4ba3db10ffd5396

## Create Network for provider
```
vi  /etc/neutron/plugins/ml2/ml2_conf.ini


[ml2_type_flat]
flat_networks = provider

vi /etc/neutron/plugins/ml2/linuxbridge_agent.ini

[linux_bridge]
physical_interface_mappings = provider:eth2

$ neutron net-create public --shared --provider:physical_network provider   --provider:network_type flat

$ neutron subnet-create public 192.168.20.0/24 --name public \
  --allocation-pool start=192.168.20.100,end=192.168.20.200\
  --dns-nameserver 8.8.8.8 --gateway 192.168.20.1
```
ref http://docs.openstack.org/liberty/install-guide-ubuntu/launch-instance-networks-public.html
http://docs.openstack.org/mitaka/install-guide-ubuntu/launch-instance.html#launch-instance-networks







