#!/bin/sh

mysql -u root -p << EOF
CREATE DATABASE keystone;
GRANT ALL ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'openstacktest';
GRANT ALL ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'openstacktest';

CREATE DATABASE glance;
GRANT ALL ON glance.* TO 'glance'@'%' IDENTIFIED BY 'openstacktest';
GRANT ALL ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'openstacktest';

CREATE DATABASE neutron;
GRANT ALL ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'openstacktest';
GRANT ALL ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'openstacktest';

CREATE DATABASE nova;
GRANT ALL ON nova.* TO 'nova'@'%' IDENTIFIED BY 'openstacktest';
GRANT ALL ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'openstacktest';

CREATE DATABASE cinder;
GRANT ALL ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'openstacktest';
GRANT ALL ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'openstacktest';

CREATE DATABASE heat;
GRANT ALL ON heat.* TO 'heat'@'%' IDENTIFIED BY 'openstacktest';
GRANT ALL ON heat.* TO 'heat'@'localhost' IDENTIFIED BY 'openstacktest';
EOF
