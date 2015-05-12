#! /bin/bash

export SERVICE_TOKEN=ADMIN
export SERVICE_ENDPOINT=http://localhost:35357/v2.0
export SERVICE_ENDPOINT_V3=http://localhost:5000/v3
KEYSTONE_IP=localhost
KEYSTONE_ADMIN_PORT=35357
KEYSTONE_SERVICE_PORT=5000

SWIFT_API_IP=192.168.22.100


function get_id () {
    echo `"$@" | grep ' id ' | awk '{print $4}'`
}

function get_id_v3 () {
    echo `"$@" | python -mjson.tool | grep '"id"' | cut -d '"' -f 4`
}


### Roles ###

ADMIN_ROLE=$(get_id keystone role-create --name=admin)
MEMBER_ROLE=$(get_id keystone role-create --name="_member_")
SWIFT_USER_ROLE=$(get_id keystone role-create --name="swift-user")

### Services ###
KEYSTONE_SERVICE=$(get_id \
keystone service-create --name=keystone \
                        --type=identity \
                        --description="Keystone Identity Service")

SWIFT_SERVICE=$(get_id \
keystone service-create --name=swift \
                        --type=object-store \
                        --description="Swift Object Storage Service")

### Endpoints ###

if [[ -z "$DISABLE_ENDPOINTS" ]]; then
    keystone endpoint-create --region RegionOne --service-id $KEYSTONE_SERVICE \
        --publicurl "http://$KEYSTONE_IP:$KEYSTONE_ADMIN_PORT/v2.0" \
        --adminurl "http://$KEYSTONE_IP:$KEYSTONE_SERVICE_PORT/v2.0" \
        --internalurl "http://$KEYSTONE_IP:$KEYSTONE_ADMIN_PORT/v2.0"
fi

if [[ -z "$DISABLE_ENDPOINTS" ]]; then
    keystone endpoint-create --region RegionOne --service-id $SWIFT_SERVICE \
        --publicurl   "http://$SWIFT_API_IP/v1/KEY_\$(tenant_id)s" \
        --adminurl    "http://$SWIFT_API_IP/v1" \
        --internalurl "http://$SWIFT_API_IP/v1/KEY_\$(tenant_id)s"
fi


### Add Domain ###
function create_domain () {
    uuid=$(get_id_v3 curl -s -X POST $SERVICE_ENDPOINT_V3/domains  -H "x-auth-token: $SERVICE_TOKEN" -H "Content-Type: application/json" -d '{ "domain": { "name": "'"$1"'"}}')
    echo $uuid
}

### Add projects in different domains ###
function add_projects () {
    if [ "$1" == "SS" ] || [ "$1" == "service" ]
        then
            pname=$1
    else
            pname="$2-$1"
    fi

    uuid=$(get_id_v3 curl -s -X POST $SERVICE_ENDPOINT_V3/projects -H "x-auth-token: $SERVICE_TOKEN" -H "Content-Type: application/json" -d \
    '{
        "project": {
            "description": "'"Test Project $1"'",
            "domain_id": "'"$3"'",
            "enabled": true,
            "name": "'"$pname"'"
        }
    }')
    echo $uuid
}

### Add users and associate role to project
function add_users_and_role (){

    uuid=$(get_id_v3 curl -s -X POST $SERVICE_ENDPOINT_V3/users -H "x-auth-token: $SERVICE_TOKEN" -H "Content-Type: application/json" -d  \
    '{
        "user": {
            "default_project_id": "'"$2"'",
            "description": "Test User",
            "domain_id": "'"$3"'",
            "email": "'"$1@test.com"'",
            "enabled": true,
            "name": "'"$1"'",
            "password": "password"
        }
    }')
    grant_role $1 $2 $3 $4
    grant_role $1 $2 $3 $SWIFT_USER_ROLE
}

function grant_role () {
    #Grant role
    curl -si -X PUT $SERVICE_ENDPOINT_V3/projects/$2/users/$uuid/roles/$4 -H "x-auth-token: $SERVICE_TOKEN"
    echo $uuid
}


#add_services
#add_endpoints
#add_roles

D1_ID=$(create_domain "d1")
D2_ID=$(create_domain "d2")

SERVICE_PRO=$(add_projects "service" "default" "default")
SS_PRO=$(add_projects "SS" "default" "default")
PRO1=$(add_projects "pro1" "default" "default")
PRO2=$(add_projects "pro2" "d1" $D1_ID)
PRO3=$(add_projects "pro3" "d1" $D1_ID)
PRO4=$(add_projects "pro4" "d2" $D2_ID)
PRO5=$(add_projects "pro5" "d2" $D2_ID)


### Add user username, projectname, domain, role
add_users_and_role "keystone" $SERVICE_PRO "default" $ADMIN_ROLE
add_users_and_role "swift" $SERVICE_PRO "default" $ADMIN_ROLE
add_users_and_role "swiftstack" $SS_PRO "default" $MEMBER_ROLE

add_users_and_role "admin-pro1" $PRO1 "default" $ADMIN_ROLE
add_users_and_role "default-pro1-u1" $PRO1 "default" $MEMBER_ROLE
add_users_and_role "default-pro1-u2" $PRO1 "default" $MEMBER_ROLE
add_users_and_role "default-pro1-u3" $PRO1 "default" $MEMBER_ROLE

add_users_and_role "admin-pro2" $PRO2 $D1_ID $ADMIN_ROLE
add_users_and_role "d1-pro2-u4" $PRO2 $D1_ID $MEMBER_ROLE
add_users_and_role "d1-pro2-u5" $PRO2 $D1_ID $MEMBER_ROLE

add_users_and_role "admin-pro3" $PRO3 $D1_ID $ADMIN_ROLE
add_users_and_role "d1-pro3-u6" $PRO3 $D1_ID $MEMBER_ROLE
add_users_and_role "d1-pro4-u7" $PRO3 $D1_ID $MEMBER_ROLE

add_users_and_role "admin-pro4" $PRO4 $D2_ID $ADMIN_ROLE
add_users_and_role "d2-pro4-u8" $PRO4 $D2_ID $MEMBER_ROLE
add_users_and_role "d2-pro4-u9" $PRO4 $D2_ID $MEMBER_ROLE

add_users_and_role "admin-pro5" $PRO5 $D2_ID $ADMIN_ROLE
add_users_and_role "d2-pro5-u10" $PRO5 $D2_ID $MEMBER_ROLE
add_users_and_role "d2-pro5-u11" $PRO5 $D2_ID $MEMBER_ROLE
