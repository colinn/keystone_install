#!/usr/bin/env bash 

set -e

ORIGINAL_DIR=$(pwd)

#FIX me
#PASSWORD=password

apt-get update ; apt-get -y install git python-pip

# Upgrade pip itself
pip install --upgrade pip
hash -r
pip install --upgrade pbr
pip install python-keystoneclient==0.9.0

#To pin the version to 0.9.1. Due to 0.9.2 has bug.
pip install sqlalchemy-migrate==0.9.1

# pin the paste version
pip install paste==1.7.5.1

#For compiling dependencies of several pip libraries , you need to install following packages first
apt-get install -y gcc python-dev libxml2-dev libxslt-dev zlib1g-dev

#Clone the Keystone Source code from GitHub and check the stable/grizzly version
cd /opt ; git clone https://github.com/openstack/keystone.git ; cd /opt/keystone
git checkout -b swiftstack-test 8d008af4d611376659ddad9cdce56bd2f1396c41

# Install packages from local cache
pip install -r /opt/keystone/requirements.txt

echo "=================================Starting to install KEYSTONE==========================================="
echo
echo
cd /opt/keystone ; python setup.py install

# Create Keystone configurartion Folder
mkdir -p /etc/keystone ; cd /etc/keystone ; cp /opt/keystone/etc/* /etc/keystone/
rename 's/\.sample//' /etc/keystone/*.sample


#Prepare MySQL 
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password swiftstack'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password swiftstack'
apt-get -y install mysql-server python-mysqldb
mysql -uroot -pswiftstack -e "CREATE DATABASE keystone"
mysql -uroot -pswiftstack -e "GRANT ALL ON keystone.* TO 'keystone'@'*' IDENTIFIED BY 'swiftstack'"
mysql -uroot -pswiftstack -e "GRANT ALL ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'swiftstack'"
sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
sudo service mysql restart

#Configuration Section

sed -e 's/# connection = sqlite:\/\/\/keystone.db/connection = mysql:\/\/keystone:swiftstack@localhost\/keystone/' -i /etc/keystone/keystone.conf
sed -e 's/# driver = keystone.token.backends.sql.Token/driver = keystone.token.backends.sql.Token/g' -i keystone.conf
sed -e 's/# provider =/provider = keystone.token.providers.uuid.Provider/g' -i keystone.conf
sed 's/ec2_extension user_crud_extension/ec2_extension s3_extension user_crud_extension/' -i /etc/keystone/keystone-paste.ini

#enable logs
sed -e 's/# debug = False/debug = True/g' -i keystone.conf
sed -e 's/# verbose = False/verbose = True/g' -i keystone.conf
sed -e 's/# log_file = keystone.log/log_file = keystone.log/g' -i keystone.conf
sed -e 's/# log_dir = \/var\/log\/keystone/log_dir = \/var\/log\/keystone/g' -i keystone.conf

#Add keystone user
useradd keystone

#Create log folder
mkdir /var/log/keystone  
sleep 2 

#Populate Data into keystone DB
keystone-manage db_sync
chown -R keystone:keystone /var/log/keystone

sleep 1
# Copy upstart and service start script 
################## UPSTART ######################

cd $ORIGINAL_DIR ; cp keystone-init.d /etc/init.d/keystone ; cp keystone.conf-init /etc/init/keystone.conf

service keystone start 
sleep 3
service keystone status

################################################

###### Inject Sample Data ######
CONTROLLER_PUBLIC_ADDRESS=${CONTROLLER_PUBLIC_ADDRESS:-localhost}
CONTROLLER_ADMIN_ADDRESS=${CONTROLLER_ADMIN_ADDRESS:-localhost}
CONTROLLER_INTERNAL_ADDRESS=${CONTROLLER_INTERNAL_ADDRESS:-localhost}

#TOOLS_DIR=$(cd $(dirname "$0") && pwd)
export SERVICE_TOKEN=`./config_service_token`
CONFIG_ADMIN_PORT=`./config_admin_port`
CONFIG_PUBLIC_PORT=`./config_public_port`
export SERVICE_ENDPOINT=`./service_endpoint`

function get_id () {
    echo `"$@" | grep ' id ' | awk '{print $4}'`
}



echo "===================================ENV VAR============================"
#
# Default tenant
#
DEMO_TENANT=$(get_id keystone tenant-create --name=demo \
                                            --description "Default Tenant")

ADMIN_USER=$(get_id keystone user-create --name=admin \
                                         --pass=secret)

ADMIN_ROLE=$(get_id keystone role-create --name=admin)

keystone user-role-add --user-id $ADMIN_USER \
                       --role-id $ADMIN_ROLE \
                       --tenant-id $DEMO_TENANT

#
# Service tenant
#
SERVICE_TENANT=$(get_id keystone tenant-create --name=service \
                                               --description "Service Tenant")

SWIFT_USER=$(get_id keystone user-create --name=swift \
                                         --pass=password \
                                         --tenant-id $SERVICE_TENANT)

keystone user-role-add --user-id $SWIFT_USER \
                       --role-id $ADMIN_ROLE \
                       --tenant-id $SERVICE_TENANT


#
# Keystone service
#
KEYSTONE_SERVICE=$(get_id \
keystone service-create --name=keystone \
                        --type=identity \
                        --description="Keystone Identity Service")
if [[ -z "$DISABLE_ENDPOINTS" ]]; then
    keystone endpoint-create --region RegionOne --service-id $KEYSTONE_SERVICE \
        --publicurl "http://$CONTROLLER_PUBLIC_ADDRESS:$CONFIG_PUBLIC_PORT/v2.0" \
        --adminurl "http://$CONTROLLER_ADMIN_ADDRESS:$CONFIG_ADMIN_PORT/v2.0" \
        --internalurl "http://$CONTROLLER_INTERNAL_ADDRESS:$CONFIG_PUBLIC_PORT/v2.0"
fi

#
# default swift service / user
#
if [[ -n $1 ]];
then
    ./default_keystone_config.sh $1
else
    echo "To install a default swift service and user, run ./default_keystone_config.sh"
fi

./keystone_middleware_settings

echo "========== DB information =========="
echo "user : root"
echo "password : swiftstack"
echo ""
echo ""
echo "========== Service Information ========="
echo "Service Token: $SERVICE_TOKEN"
echo "Service Endpoint: $SERVICE_ENDPOINT"
TENANT_TOKEN=`./tenant_token`
echo "Tenant Token: $TENANT_TOKEN"
echo ""
echo ""
echo "=====Done====="





