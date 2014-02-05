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

HOST_IP=10.10.10.51
EXT_HOST_IP=192.168.1.251

MYSQL_USER=keystone
MYSQL_DATABASE=keystone
MYSQL_HOST=$HOST_IP
MYSQL_PASSWORD=openstacktest
ADMIN_PASSWORD=${ADMIN_PASSWORD:-openstacktest}
SERVICE_PASSWORD=${SERVICE_PASSWORD:-openstacktest}
export SERVICE_TOKEN="ADMIN"
export SERVICE_ENDPOINT="http://${HOST_IP}:35357/v2.0"
SERVICE_TENANT_NAME=${SERVICE_TENANT_NAME:-service}
KEYSTONE_REGION=RegionOne


get_id() {
	echo `$@ | awk '/ id / { print $4 }'`
}

# Tenants
ADMIN_TENANT=$(get_id keystone tenant-create --name admin)
SERVICE_TENANT=$(get_id keystone tenant-create --name $SERVICE_TENANT_NAME)

# Users
ADMIN_USER=$(get_id keystone user-create --name admin --pass "$ADMIN_PASSWORD" --email admin@domain.com)

# Roles
MEMBER_ROLE=$(get_id keystone role-create --name Member)
ADMIN_ROLE=$(get_id keystone role-create --name admin)
KEYSTONEADMIN_ROLE=$(get_id keystone role-create --name KeystoneAdmin)
KEYSTONESERVICE_ROLE=$(get_id keystone role-create --name KeystoneServiceAdmin)
KEYSTONERESELLERADMIN_ROLE=$(get_id keystone role-create --name ResellerAdmin)

# Add Roles to Users in Tenants
keystone user-role-add --user-id $ADMIN_USER --role-id $ADMIN_ROLE --tenant-id $ADMIN_TENANT
keystone user-role-add --user-id $ADMIN_USER --role-id $KEYSTONEADMIN_ROLE --tenant-id $ADMIN_TENANT
keystone user-role-add --user-id $ADMIN_USER --role-id $KEYSTONESERVICE_ROLE --tenant-id $ADMIN_TENANT

# Users
NOVA_USER=$(get_id keystone user-create --name nova --pass "$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email nova@domain.com)
GLANCE_USER=$(get_id keystone user-create --name glance --pass "$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email glance@domain.com)
NEUTRON_USER=$(get_id keystone user-create --name neutron --pass "$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email neutron@domain.com)
CINDER_USER=$(get_id keystone user-create --name cinder --pass "$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email cinder@domain.com)
SWIFT_USER=$(get_id keystone user-create --name swift --pass "$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email swift@domain.com)
CEILOMETER_USER=$(get_id keystone user-create --name ceilometer --pass "$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email ceilometer@domain.com)

# Roles
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $NOVA_USER --role-id $ADMIN_ROLE
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $GLANCE_USER --role-id $ADMIN_ROLE
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $NEUTRON_USER --role-id $ADMIN_ROLE
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $CINDER_USER --role-id $ADMIN_ROLE
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $SWIFT_USER --role-id $ADMIN_ROLE
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $CEILOMETER_USER --role-id $ADMIN_ROLE
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $CEILOMETER_USER --role-id $KEYSTONERESELLERADMIN_ROLE

# Services
NOVA_SERVICE=$(get_id keystone service-create --name nova --type compute --description Compute)
CINDER_SERVICE=$(get_id keystone service-create --name cinder --type volume --description Volume)
GLANCE_SERVICE=$(get_id keystone service-create --name glance --type image --description Image)
KEYSTONE_SERVICE=$(get_id keystone service-create --name keystone --type identity --description Identity)
EC2_SERVICE=$(get_id keystone service-create --name ec2 --type ec2 --description EC2)
NEUTRON_SERVICE=$(get_id keystone service-create --name neutron --type network --description Networking)
SWIFT_SERVICE=$(get_id keystone service-create --name swift --type object-store --description Storage)
CEILOMETER_SERVICE=$(get_id keystone service-create --name ceilometer --type metering --description Metering)

# Service endpoints
keystone endpoint-create --region $KEYSTONE_REGION --service-id $NOVA_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':8774/v2/$(tenant_id)s' --adminurl 'http://'"$HOST_IP"':8774/v2/$(tenant_id)s' --internalurl 'http://'"$HOST_IP"':8774/v2/$(tenant_id)s'
keystone endpoint-create --region $KEYSTONE_REGION --service-id $CINDER_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':8776/v1/$(tenant_id)s' --adminurl 'http://'"$HOST_IP"':8776/v1/$(tenant_id)s' --internalurl 'http://'"$HOST_IP"':8776/v1/$(tenant_id)s'
keystone endpoint-create --region $KEYSTONE_REGION --service-id $GLANCE_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':9292/v2' --adminurl 'http://'"$HOST_IP"':9292/v2' --internalurl 'http://'"$HOST_IP"':9292/v2'
keystone endpoint-create --region $KEYSTONE_REGION --service-id $KEYSTONE_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':5000/v2.0' --adminurl 'http://'"$HOST_IP"':35357/v2.0' --internalurl 'http://'"$HOST_IP"':5000/v2.0'
keystone endpoint-create --region $KEYSTONE_REGION --service-id $EC2_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':8773/services/Cloud' --adminurl 'http://'"$HOST_IP"':8773/services/Admin' --internalurl 'http://'"$HOST_IP"':8773/services/Cloud'
keystone endpoint-create --region $KEYSTONE_REGION --service-id $NEUTRON_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':9696' --adminurl 'http://'"$HOST_IP"':9696' --internalurl 'http://'"$HOST_IP"':9696'
keystone endpoint-create --region $KEYSTONE_REGION --service-id $SWIFT_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':8080/v1/AUTH_%(tenant_id)s' --adminurl 'http://'"$HOST_IP"':8080/' --internalurl 'http://'"$HOST_IP"':8080/v1/AUTH_%(tenant_id)s'
keystone endpoint-create --region $KEYSTONE_REGION --service-id $CEILOMETER_SERVICE --publicurl 'http://'"$EXT_HOST_IP"':8777' --adminurl 'http://'"$HOST_IP"':8777' --internalurl 'http://'"$HOST_IP"':8777'
