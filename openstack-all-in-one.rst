================================
  OpenStack Havana Install Guide
================================
Thi guide is heavily based on `Marco Fornaro's <http://www.linkedin.com/profile/view?id=49858164>`_ <marco.fornaro@gmail.com> `installation guide <https://github.com/fornyx/OpenStack-Havana-Install-Guide>`_


.. contents::


Requirements
============

Network
-------
Two NICs are required and static addresses must be configured on them::

   eth0: 10.10.10.51
   eth1: 192.168.1.251

*If your host is a virtual machine (VMWare or VirtualBox) then eth0 should a NAT adapter and eth1 should be a Bridged adapter*

Operating system
----------------
Ubuntu 12.04 Server 64-bit


Preparing your node
===================

Networking
----------
Only one NIC should have Internet access, the other is for Openstack internal communication::

   # Not Internet connected (OpenStack management network)
   auto eth0
   iface eth0 inet static
      address 10.10.10.51
      netmask 255.255.255.0

   # For exposing OpenStack API over the Internet
   auto eth1
   iface eth1 inet static
      address 192.168.1.251
      netmask 255.255.255.0
      gateway 192.168.1.1
      dns-nameservers 192.168.1.1

*Please note that in this architecture the DNS nameserver and the default gateway are the same*

Enable udev persistent net. Add the following to :code:`/etc/udev/rules.d/70-persistent-net.rules`::

   SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="<eth0_mac_address>", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth0"
   SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="<eth1_mac_address>", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth1"

Replace :code:`<eth0_mac_address>` and :code:`<eth1_mac_address>` with real MAC addresses of your NICs

Restart networking service (reboot if the following does not work)::

   service networking restart

Preparing Ubuntu
-----------------
Add Havana repositories::

   apt-get -y install ubuntu-cloud-keyring python-software-properties software-properties-common python-keyring
   echo deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-proposed/havana main >> /etc/apt/sources.list.d/havana.list

Update your system::

   apt-get -y update && apt-get -y upgrade && apt-get -y dist-upgrade

It could be necessary to reboot your system in case you have a kernel upgrade

MySQL, RabbitMQ, NTP
--------------------
Install necessary packages::

   apt-get install -y mysql-server python-mysqldb rabbitmq-server ntp

Configure MySQL to accept incoming connections on all interfaces::

   sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
   service mysql restart
 
Databases set up
----------------
Use the following script to create all necessary databases and users::

   wget https://raw2.github.com/Ch00k/openstack-install-aio/master/populate_database.sh
   sh populate_database.sh

Others
------
Enable IP Forwarding::

   sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

To save you from rebooting, execute the following::
   
   sysctl net.ipv4.ip_forward=1


Keystone
========

Install Keystone packages::

   apt-get install -y keystone

Adapt the connection option in the :code:`/etc/keystone/keystone.conf` to the new database::

   connection = mysql://keystone:openstacktest@10.10.10.51/keystone

Remove Keystone SQLite database::

   rm /var/lib/keystone/keystone.db

Restart the identity service then synchronize the database::

   service keystone restart
   keystone-manage db_sync

Fill up the Keystone database using the two scripts available in this repository::
   
   wget https://raw2.github.com/Ch00k/openstack-install-aio/master/populate_keystone.sh

Modify the :code:`HOST_IP` and :code:`EXT_HOST_IP` variables in both scripts if needed, then execute::

   sh populate_keystone.sh

Create a simple credential file and source it so you have your credentials loaded in your environnment::

   echo -e 'export OS_TENANT_NAME=admin\nexport OS_USERNAME=admin\nexport OS_PASSWORD=openstacktest\nexport OS_AUTH_URL="http://192.168.1.251:5000/v2.0/"' > ~/.keystonerc
   source ~/.keystonerc

Add sourcing of this file to :code:`~/.bashrc`::

   echo "source ~/.keystonerc" >> ~/.bashrc

To test if Keystone is working execute the following::

   keystone user-list


Glance
======

Install Glance packages::

   apt-get -y install glance

Update :code:`/etc/glance/glance-api.conf` and :code:`/etc/glance/glance-registry.conf` with::

   [DEFAULT]
   sql_connection = mysql://glance:openstacktest@10.10.10.51/glance

   [keystone_authtoken]
   auth_host = 10.10.10.51
   auth_port = 35357
   auth_protocol = http
   admin_tenant_name = service
   admin_user = glance
   admin_password = openstacktest

   [paste_deploy]
   flavor = keystone

Update :code:`/etc/glance/glance-api-paste.ini` and :code:`/etc/glance/glance-registry-paste.ini` with::

   [filter:authtoken]
   paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
   auth_host = 10.10.10.51
   auth_port = 35357
   auth_protocol = http
   admin_tenant_name = service
   admin_user = glance
   admin_password = openstacktest

Remove Glance's SQLite database::

   rm /var/lib/glance/glance.sqlite   

Restart Glance services::

   service glance-api restart; service glance-registry restart

Synchronize Glance database::

   glance-manage db_sync

Restart the services again to take modifications into account::

   service glance-registry restart; service glance-api restart

To test Glance, upload the cirros cloud image and Ubuntu cloud image::

   glance image-create --name "Cirros 0.3.1" --is-public true --container-format bare --disk-format qcow2 --location http://cdn.download.cirros-cloud.net/0.3.1/cirros-0.3.1-x86_64-disk.img
   wget http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-amd64-disk1.img
   glance add name="Ubuntu 12.04 cloudimg amd64" is_public=true container_format=ovf disk_format=qcow2 < precise-server-cloudimg-amd64-disk1.img
   
Now list the image to see what you have just uploaded::

   glance image-list
   

Neutron
=======

OpenVSwitch
-----------
Install OpenVSwitch::

   apt-get install -y openvswitch-controller openvswitch-switch openvswitch-datapath-dkms 

Create bridges:

br-int for VM interaction::

   ovs-vsctl add-br br-int

br-ex to give VMs access to the Internet::

   ovs-vsctl add-br br-ex

Modify network configuration of your host
Edit :code:`eth1` in :code:`/etc/network/interfaces` to look like this::

   auto eth1
   iface eth1 inet manual
      up ifconfig $IFACE 0.0.0.0 up
      up ip link set $IFACE promisc on
      down ip link set $IFACE promisc off
      down ifconfig $IFACE down

Add :code:`br-ex` inteface configuration to :code:`/etc/network/interfaces`::

   auto br-ex
   iface br-ex inet static
      address 192.168.1.251
      netmask 255.255.255.0
      gateway 192.168.1.1
      dns-nameservers 192.168.1.1

Add :code:`eth1` to :code:`br-ex`::

   ovs-vsctl add-port br-ex eth1

*Note that this will throw you out of the SSH session so you will need to reconnect*

Restart networking service (reboot if the following does not work)::

   service networking restart


Neutron
-------

Install Neutron packages::

   apt-get install -y neutron-server neutron-plugin-openvswitch neutron-plugin-openvswitch-agent dnsmasq neutron-dhcp-agent neutron-l3-agent neutron-metadata-agent

Stop neutron-server::

   service neutron-server stop

Edit :code:`/etc/neutron/neutron.conf`::

   [keystone_authtoken]
   auth_host = 10.10.10.51
   auth_port = 35357
   auth_protocol = http
   admin_tenant_name = service
   admin_user = neutron
   admin_password = openstacktest
   
   [database]
   connection = mysql://neutron:openstacktest@10.10.10.51/neutron

Edit :code:`/etc/neutron/api-paste.ini`::

   [filter:authtoken]
   paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
   auth_host = 10.10.10.51
   auth_port = 35357
   auth_protocol = http
   admin_tenant_name = service
   admin_user = neutron
   admin_password = openstacktest

Update :code:`/etc/neutron/metadata_agent.ini`::

   [DEFAULT]
   auth_url = http://10.10.10.51:35357/v2.0
   auth_region = RegionOne
   admin_tenant_name = service
   admin_user = neutron
   admin_password = openstacktest
   nova_metadata_ip = 10.10.10.51
   nova_metadata_port = 8775
   metadata_proxy_shared_secret = helloOpenStack

Edit :code:`/etc/neutron/l3_agent.ini`::

   [DEFAULT]
   interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
   use_namespaces = True
   external_network_bridge = br-ex
   signing_dir = /var/cache/neutron
   admin_tenant_name = service
   admin_user = neutron
   admin_password = openstacktest
   auth_url = http://10.10.10.51:35357/v2.0
   l3_agent_manager = neutron.agent.l3_agent.L3NATAgentWithStateReport
   root_helper = sudo neutron-rootwrap /etc/neutron/rootwrap.conf
   interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver

Edit :code:`/etc/neutron/dhcp_agent.ini`::

   [DEFAULT]
   interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
   dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
   use_namespaces = True
   signing_dir = /var/cache/neutron
   admin_tenant_name = service
   admin_user = neutron
   admin_password = openstacktest
   auth_url = http://10.10.10.51:35357/v2.0
   dhcp_agent_manager = neutron.agent.dhcp_agent.DhcpAgentWithStateReport
   root_helper = sudo neutron-rootwrap /etc/neutron/rootwrap.conf
   state_path = /var/lib/neutron

Edit the OVS plugin configuration file :code:`/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini` with::: 

   [database]
   sql_connection=mysql://neutron:openstacktest@10.10.10.51/neutron

   [ovs]
   tenant_network_type = gre
   enable_tunneling = True
   tunnel_id_ranges = 1:1000
   integration_bridge = br-int
   tunnel_bridge = br-tun
   local_ip = 10.10.10.51

   [securitygroup]
   firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

Remove Neutron's SQLite database::

   rm /var/lib/neutron/neutron.sqlite

Restart all neutron services::

   for i in $( ls /etc/init.d/neutron-* ); do service `basename $i` restart; done
   service dnsmasq restart
   
Check Neutron agents (hopefully you'll enjoy smiling faces :-* ) )::

   neutron agent-list

Nova
====

Install Nova packages::

   apt-get install -y nova-api nova-cert novnc nova-consoleauth nova-scheduler nova-novncproxy nova-doc nova-conductor nova-compute-kvm

Modify the :code:`/etc/nova/nova.conf` like this::

   [DEFAULT]
   logdir=/var/log/nova
   state_path=/var/lib/nova
   lock_path=/run/lock/nova
   api_paste_config=/etc/nova/api-paste.ini
   compute_scheduler_driver=nova.scheduler.simple.SimpleScheduler
   nova_url=http://10.10.10.51:8774/v1.1/
   sql_connection=mysql://nova:openstacktest@10.10.10.51/nova
   root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf

   # Auth
   use_deprecated_auth=false
   auth_strategy=keystone

   # Imaging service
   glance_api_servers=10.10.10.51:9292
   image_service=nova.image.glance.GlanceImageService

   # Vnc configuration
   novnc_enabled=true
   novncproxy_base_url=http://192.168.1.251:6080/vnc_auto.html
   novncproxy_port=6080
   vncserver_proxyclient_address=10.10.10.51
   vncserver_listen=0.0.0.0

   # Network settings
   network_api_class=nova.network.neutronv2.api.API
   neutron_url=http://10.10.10.51:9696
   neutron_auth_strategy=keystone
   neutron_admin_tenant_name=service
   neutron_admin_username=neutron
   neutron_admin_password=openstacktest
   neutron_admin_auth_url=http://10.10.10.51:35357/v2.0
   libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
   linuxnet_interface_driver=nova.network.linux_net.LinuxOVSInterfaceDriver
   #If you want Neutron + Nova Security groups
   #firewall_driver=nova.virt.firewall.NoopFirewallDriver
   #security_group_api=neutron
   #If you want Nova Security groups only, comment the two lines above and uncomment line -1-.
   #-1-firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver
   
   #Metadata
   service_neutron_metadata_proxy = True
   neutron_metadata_proxy_shared_secret = helloOpenStack
   metadata_host = 10.10.10.51
   metadata_listen = 10.10.10.51
   metadata_listen_port = 8775
   
   # Compute #
   compute_driver=libvirt.LibvirtDriver
   
   # Cinder #
   volume_api_class=nova.volume.cinder.API
   osapi_volume_listen_port=5900
   cinder_catalog_info=volume:cinder:internalURL

Edit the :code:`/etc/nova/nova-compute.conf`::

   [DEFAULT]
   libvirt_type=kvm
   libvirt_ovs_bridge=br-int
   libvirt_vif_type=ethernet
   libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
   libvirt_use_virtio_for_bridges=True

Modify authtoken section in :code:`/etc/nova/api-paste.ini` to this::

   [filter:authtoken]
   paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
   auth_host = 10.10.10.51
   auth_port = 35357
   auth_protocol = http
   admin_tenant_name = service
   admin_user = nova
   admin_password = openstacktest
   signing_dirname = /tmp/keystone-signing-nova
   auth_version = v2.0
    
Restart Nova services::

   for i in $( ls /etc/init.d/nova-* ); do service `basename $i` restart; done

Remove Nova's SQLite database::

   rm /var/lib/nova/nova.sqlite

Synchronize your database::

   nova-manage db sync

Restart Nova services::

   for i in $( ls /etc/init.d/nova-* ); do service `basename $i` restart; done

Hopefully you should enjoy smiling faces on Nova services to confirm your installation::

   nova-manage service list
   

Cinder
======

Install Cinder packages::

   apt-get install -y cinder-api cinder-scheduler cinder-volume

Create and mount a loopback device to be used as the volume group for Cinder volumes, then create the volume group::

   dd if=/dev/zero of=/opt/cinder-volumes bs=1 count=0 seek=100G
   losetup /dev/loop2 /opt/cinder-volumes
   pvcreate /dev/loop2
   vgcreate cinder-volumes /dev/loop2

To make the loopback device persistent between reboots add the following to :code:`/etc/rc.local` (before :code:`exit 0` line!)::

   losetup /dev/loop2 /opt/cinder-volumes

Edit the :code:`/etc/cinder/cinder.conf` to::

   [DEFAULT]
   rootwrap_config=/etc/cinder/rootwrap.conf
   sql_connection = mysql://cinder:openstacktest@10.10.10.51/cinder
   api_paste_config = /etc/cinder/api-paste.ini
   iscsi_helper=ietadm
   volume_name_template = volume-%s
   volume_group = cinder-volumes
   auth_strategy = keystone
   volume_clear = none

Configure :code:`/etc/cinder/api-paste.ini` like the following::

   [filter:authtoken]
   paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
   service_protocol = http
   service_host = 192.168.1.251
   service_port = 5000
   auth_host = 10.10.10.51
   auth_port = 35357
   auth_protocol = http
   admin_tenant_name = service
   admin_user = cinder
   admin_password = openstacktest

Remove Cinder's SQLite database::

   rm /var/lib/cinder/cinder.sqlite

Then, synchronize the database::

   cinder-manage db sync

Restart the cinder services::

   for i in $( ls /etc/init.d/cinder-* ); do service `basename $i` restart; done


Swift
=====

Install Swift packages::

   apt-get -y install swift swift-account swift-container swift-object swift-proxy openssh-server memcached python-pip python-netifaces python-xattr python-memcache xfsprogs python-keystoneclient python-swiftclient python-webob git

Create configuration diretory::

   mkdir -p /etc/swift && chown -R swift:swift /etc/swift/

Create :code:`/etc/swift/swift.conf` like the following::

   [swift-hash]
   swift_hash_path_suffix = openstacktest

Create and mount an XFS partition for object storage::
   
   dd if=/dev/zero of=/opt/swift-objects bs=1 count=0 seek=50G
   losetup /dev/loop3 /opt/swift-objects
   mkfs.xfs /dev/loop3
   mkdir -p /srv/node/sdb
   mount /dev/loop3 /srv/node/sdb
   chown -R swift:swift /srv/node

To make the loopback device persistent between reboots add the following to :code:`/etc/rc.local` (before :code:`exit 0` line!)::

   losetup /dev/loop3 /opt/swift-objects
   mount /dev/loop3 /srv/node/sdb

Create self-signed cert for SSL::

   openssl req -new -x509 -nodes -out /etc/swift/cert.crt -keyout /etc/swift/cert.key

Because the distribution packages do not include a copy of the keystoneauth middleware, ensure that the proxy server includes them::

   git clone https://github.com/openstack/swift.git && cd swift && python setup.py install

Create :code:`/etc/swift/proxy-server.conf`::

   [DEFAULT]
   bind_port = 8080
   user = swift

   [pipeline:main]
   pipeline = healthcheck cache authtoken keystoneauth proxy-server
   
   [app:proxy-server]
   use = egg:swift#proxy
   allow_account_management = true
   account_autocreate = true
   
   [filter:keystoneauth]
   use = egg:swift#keystoneauth
   operator_roles = Member,admin,swiftoperator
   
   [filter:authtoken]
   paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
   delay_auth_decision = true
   signing_dir = /home/swift/keystone-signing
   auth_protocol = http
   auth_host = 10.10.10.51
   auth_port = 35357
   admin_token = openstacktest
   admin_tenant_name = service
   admin_user = swift
   admin_password = openstacktest
   
   [filter:cache]
   use = egg:swift#memcache
   
   [filter:catch_errors]
   use = egg:swift#catch_errors
   
   [filter:healthcheck]
   use = egg:swift#healthcheck

Create the :code:`signing_dir` and set its permissions accordingly::
   
   mkdir -p /home/swift/keystone-signing && chown -R swift:swift /home/swift/keystone-signing

Create the account, container, and object rings::

   cd /etc/swift
   swift-ring-builder account.builder create 18 3 1
   swift-ring-builder container.builder create 18 3 1
   swift-ring-builder object.builder create 18 3 1

Add entries to each ring::

   swift-ring-builder account.builder add z1-10.10.10.51:6002/sdb 100
   swift-ring-builder container.builder add z1-10.10.10.51:6001/sdb 100
   swift-ring-builder object.builder add z1-10.10.10.51:6000/sdb 100

Rebalance the rings::

   swift-ring-builder account.builder rebalance
   swift-ring-builder container.builder rebalance
   swift-ring-builder object.builder rebalance

Make sure the swift user owns all configuration files::

   chown -R swift:swift /etc/swift

Start Swift services::

   swift-init main start && service rsyslog restart && service memcached restart


Ceilometer
==========

Install the required packages::

   apt-get -y install ceilometer-api ceilometer-collector ceilometer-agent-central python-ceilometerclient ceilometer-agent-compute mongodb

Change :code:`bind_ip` in :code:`/etc/mongodb.conf`::

   sed -i 's/127.0.0.1/10.10.10.51/g' /etc/mongodb.conf

Restart the MongoDB service::

   service mongodb restart

Create the database and a ceilometer database user::

   mongo --host 10.10.10.51
   > use ceilometer
   > db.addUser( { user: "ceilometer",
                 pwd: "openstacktest",
                 roles: [ "readWrite", "dbAdmin" ]
               } )

Edit :code:`/etc/ceilometer/ceilometer.conf` like so::

   [DEFAULT]
   log_dir = /var/log/ceilometer

   [database]
   connection = mongodb://ceilometer:openstacktest@10.10.10.51:27017/ceilometer

   [publisher_rpc]
   metering_secret = openstacktest

   [keystone_authtoken]
   auth_host = 10.10.10.51
   auth_port = 35357
   auth_protocol = http
   admin_tenant_name = service
   admin_user = ceilometer
   admin_password = openstacktest

   [service_credentials]
   os_username = ceilometer
   os_tenant_name = service
   os_password = openstacktest

Restart Ceilometer services::

   for i in $( ls /etc/init.d/ceilometer-* ); do service `basename $i` restart; done

Enable Compute agent

Add the following to :code:`[DEFAULT]` section of :code:`/etc/nova/nova.conf`::

   instance_usage_audit = True
   instance_usage_audit_period = hour
   notify_on_state_change = vm_and_task_state
   notification_driver = nova.openstack.common.notifier.rpc_notifier
   notification_driver = ceilometer.compute.nova_notifier

Restart compute agent::

   service ceilometer-agent-compute restart

Enable Glance agent::

Add the following to :code:`[DEFAULT]` section of :code:`/etc/glance/glance-api.conf`::

   notifier_strategy = rabbit

Restart Glance services::

   service glance-registry restart && service glance-api restart

Enable Cinder agent::

Add the following to :code:`[DEFAULT]` section of :code:`/etc/cinder/cinder.conf`::

   control_exchange = cinder
   notification_driver = cinder.openstack.common.notifier.rpc_notifier

Restart Cinder services::

   service cinder-volume restart && service cinder-api restart

Enable Swift agent::

Add the following to :code:`/etc/swift/proxy-server.conf`::

   [filter:ceilometer]
   use = egg:ceilometer#swift

Add ceilometer to the pipeline parameter of that same file::

   [pipeline:main]
   pipeline = healthcheck cache authtoken keystoneauth ceilometer proxy-server

A workaround for https://bugs.launchpad.net/ceilometer/+bug/1262264::

   chmod 777 /var/log/ceilometer

Restart Swift proxy server::

   swift-init proxy restart


Heat
====

Install Heat packages::

   apt-get -y install heat-api heat-api-cfn heat-engine

Edit :code:`/etc/heat/heat.conf` like so::

   [DEFAULT]
   sql_connection = mysql://heat:openstacktest@10.10.10.51/heat
   verbose = True
   log_dir = /var/log/heat

   [keystone_authtoken]
   auth_host = 10.10.10.51
   auth_port = 35357
   auth_protocol = http
   auth_uri = http://10.10.10.51:5000/v2.0
   admin_tenant_name = service
   admin_user = heat
   admin_password = openstacktest

   [ec2_authtoken]
   auth_uri = http://10.10.10.51:5000/v2.0
   keystone_ec2_uri = http://10.10.10.51:5000/v2.0/ec2tokens

Workaround for https://bugs.launchpad.net/devstack/+bug/1217334::

   mkdir /etc/heat/environment.d
   wget https://raw2.github.com/openstack/heat/master/etc/heat/environment.d/default.yaml -O /etc/heat/environment.d/default.yaml

Synchronize Heat database::

   heat-manage db_sync

Restart Heat services::

   for i in $( ls /etc/init.d/heat-* ); do service `basename $i` restart; done


Horizon
=======

Install Horizon packages and remove Ubuntu Horizon theme::

   apt-get -y install openstack-dashboard memcached && dpkg --purge openstack-dashboard-ubuntu-theme

Reload Apache and memcached::

   service apache2 restart; service memcached restart

You can now access your OpenStack installation :code:`192.168.1.251/horizon` with credentials :code:`admin:openstacktest`.


Licensing
=========

This OpenStack Havana Install Guide is licensed under a Creative Commons Attribution 3.0 Unported License.

.. image:: http://i.imgur.com/4XWrp.png
To view a copy of this license, visit [ http://creativecommons.org/licenses/by/3.0/deed.en_US ].
