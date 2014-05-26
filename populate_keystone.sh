#!/bin/sh
#
# Keystone basic configuration 
#
# Mainly inspired by https://github.com/openstack/keystone/blob/master/tools/sample_data.sh
#
# Modified by Bilel Msekni / Institut Telecom
#
# Modified by Marco Fornaro / Huawei - ERC Munich
#
# Modified by Andriy Yurchuk
#
#
# Support: openstack@lists.launchpad.net
# License: Apache Software License (ASL) 2.0
#

HOST_IP=
EXT_HOST_IP=

ADMIN_PASSWORD=
SERVICE_PASSWORD=
export SERVICE_TOKEN="ADMIN"
export SERVICE_ENDPOINT="http://${HOST_IP}:35357/v2.0"

get_id() {
	echo `$@ | awk '/ id / { print $4 }'`
}

# Tenants
keystone tenant-create --name admin
keystone tenant-create --name service

# Users
keystone user-create --name admin --pass "$ADMIN_PASSWORD" --email admin@domain.com

# Roles
keystone role-create --name Member
keystone role-create --name admin
keystone role-create --name KeystoneAdmin
keystone role-create --name KeystoneServiceAdmin
keystone role-create --name ResellerAdmin

# Users
keystone user-create --name nova --pass "$SERVICE_PASSWORD" --email nova@domain.com
keystone user-create --name glance --pass "$SERVICE_PASSWORD" --email glance@domain.com
keystone user-create --name neutron --pass "$SERVICE_PASSWORD" --email neutron@domain.com
keystone user-create --name cinder --pass "$SERVICE_PASSWORD" --email cinder@domain.com
keystone user-create --name swift --pass "$SERVICE_PASSWORD" --email swift@domain.com
keystone user-create --name ceilometer --pass "$SERVICE_PASSWORD" --email ceilometer@domain.com
keystone user-create --name heat --pass "$SERVICE_PASSWORD" --email heat@domain.com

# Roles
keystone user-role-add --tenant admin --user admin --role admin 
keystone user-role-add --tenant admin --user admin --role KeystoneAdmin
keystone user-role-add --tenant admin --user admin --role KeystoneServiceAdmin

keystone user-role-add --tenant service --user nova --role admin
keystone user-role-add --tenant service --user glance --role admin
keystone user-role-add --tenant service --user neutron --role admin
keystone user-role-add --tenant service --user cinder --role admin
keystone user-role-add --tenant service --user swift --role admin
keystone user-role-add --tenant service --user ceilometer --role admin
keystone user-role-add --tenant service --user ceilometer --role ResellerAdmin
keystone user-role-add --tenant service --user heat --role admin

# Services
NOVA_SERVICE=$(get_id keystone service-create --name nova --type compute --description Compute)
CINDER_SERVICE=$(get_id keystone service-create --name cinder --type volume --description Volume)
GLANCE_SERVICE=$(get_id keystone service-create --name glance --type image --description Image)
KEYSTONE_SERVICE=$(get_id keystone service-create --name keystone --type identity --description Identity)
EC2_SERVICE=$(get_id keystone service-create --name ec2 --type ec2 --description EC2)
NEUTRON_SERVICE=$(get_id keystone service-create --name neutron --type network --description Networking)
SWIFT_SERVICE=$(get_id keystone service-create --name swift --type object-store --description Storage)
CEILOMETER_SERVICE=$(get_id keystone service-create --name ceilometer --type metering --description Metering)
HEAT_SERVICE=$(get_id keystone service-create --name heat --type orchestration --description Orchestration)
CFN_SERVICE=$(get_id keystone service-create --name heat-cfn --type cloudformation --description Cloudformation)

# Service endpoints
keystone endpoint-create --region RegionOne --service-id $NOVA_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':8774/v2/$(tenant_id)s' --adminurl 'http://'"$HOST_IP"':8774/v2/$(tenant_id)s' --internalurl 'http://'"$HOST_IP"':8774/v2/$(tenant_id)s'
keystone endpoint-create --region RegionOne --service-id $CINDER_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':8776/v1/$(tenant_id)s' --adminurl 'http://'"$HOST_IP"':8776/v1/$(tenant_id)s' --internalurl 'http://'"$HOST_IP"':8776/v1/$(tenant_id)s'
keystone endpoint-create --region RegionOne --service-id $GLANCE_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':9292' --adminurl 'http://'"$HOST_IP"':9292' --internalurl 'http://'"$HOST_IP"':9292'
keystone endpoint-create --region RegionOne --service-id $KEYSTONE_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':5000/v2.0' --adminurl 'http://'"$HOST_IP"':35357/v2.0' --internalurl 'http://'"$HOST_IP"':5000/v2.0'
keystone endpoint-create --region RegionOne --service-id $EC2_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':8773/services/Cloud' --adminurl 'http://'"$HOST_IP"':8773/services/Admin' --internalurl 'http://'"$HOST_IP"':8773/services/Cloud'
keystone endpoint-create --region RegionOne --service-id $NEUTRON_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':9696' --adminurl 'http://'"$HOST_IP"':9696' --internalurl 'http://'"$HOST_IP"':9696'
keystone endpoint-create --region RegionOne --service-id $SWIFT_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':8080/v1/AUTH_%(tenant_id)s' --adminurl 'http://'"$HOST_IP"':8080' --internalurl 'http://'"$HOST_IP"':8080/v1/AUTH_%(tenant_id)s'
keystone endpoint-create --region RegionOne --service-id $CEILOMETER_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':8777' --adminurl 'http://'"$HOST_IP"':8777' --internalurl 'http://'"$HOST_IP"':8777'
keystone endpoint-create --region RegionOne --service-id $HEAT_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':8004/v1/$(tenant_id)s' --adminurl 'http://'"$HOST_IP"':8004/v1/$(tenant_id)s' --internalurl 'http://'"$HOST_IP"':8004/v1/$(tenant_id)s'
keystone endpoint-create --region RegionOne --service-id $CFN_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':8000/v1' --adminurl 'http://'"$HOST_IP"':8000/v1' --internalurl 'http://'"$HOST_IP"':8000/v1'
