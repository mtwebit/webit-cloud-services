#!/bin/bash
#
# Webit Cloud Services Toolkit - LDAP server
#
# Copyright 2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="LDAP authentication"
desc="Provides user authentication."

# most of these docker images are pretty buggy...
#dockerimage="osixia/openldap"
#dockerimage="mwaeckerlin/openldap"
# https://github.com/gitphill/ldap-alpine
dockerimage="pgarrett/ldap-alpine"

# Variables set by the caller script
# $servicedir: this directory
# $containername: human-readable name of the container
# $serviceconf: config file in the deployment storing variables set by the user

# Use this if you use a custom image repo
# docker_auth REPO USER TOKEN

# Set up the container if it does not exists
if ! container_exists $containername; then
  if [ -z "$ldap_domain" ]; then
    ldap_domain="${wbdomain}"
    ldap_basedn="dc=${ldap_domain//./,dc=}"
    ldap_org="$wbname"
    ldap_manager="admin"
    ldap_manager_email="${wbemail}"
    ldap_pw=`generate_password`
    siport=389
  fi
  webaccess="n"
  service_setup
  ask ldap_org "LDAP organization name" "$ldap_org"
  remember "$serviceconf" ldap_org
  ask ldap_domain "LDAP domain name" "$ldap_domain"
  remember "$serviceconf" ldap_domain
  ldap_basedn="dc=${ldap_domain//./,dc=}"
  ask ldap_basedn "LDAP base DN" "$ldap_basedn"
  remember "$serviceconf" ldap_basedn
# TODO this ldap docker image does not support chaning the admin name
  ask ldap_manager "LDAP manager username" "$ldap_manager"
  remember "$serviceconf" ldap_manager
  #ask ldap_manager_email "LDAP manager email" "$ldap_manager_email"
  #remember "$serviceconf" ldap_manager_email
  ask ldap_pw "LDAP manager password" $ldap_pw
  remember "$serviceconf" ldap_pw
  # Do not create any user, we need to create a new schema
  #  --env USER_UID="${ldap_manager}" \
  #  --env USER_GIVEN_NAME="Admin" \
  #  --env USER_SURNAME="LDAP" \
  #  --env USER_EMAIL="${ldap_manager_email}" \
  #  --env USER_PW="$ldap_pw" \
  container_setup "$dockerimage" $containername \
    --env ORGANISATION_NAME=\"$ldap_org\" \
    --env SUFFIX="$ldap_basedn" \
    --env ACCESS_CONTROL='"access to * by self write by anonymous read"' \
    --env ROOT_PW="$ldap_pw" \
    --env DOMAIN=$ldap_domain \
    --env HOSTNAME=$containername \
    --env ROOT_USER=${ldap_manager} \
    -v ${servicedatadir}/ldif-init:/ldif \
    -v ${servicedatadir}/openldap-data:/var/lib/openldap/openldap-data
  container_start $containername
  while ! container_running $containername ; do
    sleep 5;
    debug "Waiting for $containername to start..."
  done
  # install the LDAP clients
  debug -n "Installing LDAP client utilities..."
  # Sometimes there are networking problems with containers
  while [ "`docker exec -it $containername sh -c "ls /usr/bin/ldapsearch" | grep -c "No such"`" == "1" ]; do
    docker exec $containername sh -c 'timeout -t 8 apk update' 2>/dev/null >/dev/null
    docker exec $containername sh -c 'timeout -t 5 apk add --no-cache openldap-clients' 2>/dev/null >/dev/null
    sleep 2
  done
  debug -c "done."
  debug -n "Configuring LDAP schemas and directory entries..."
  # remove the dummy user and group
  docker exec $containername sh -c "ldapdelete -x -D cn=${ldap_manager},${ldap_basedn} -w ${ldap_pw} uid=pgarrett,ou=Users,${ldap_basedn}"
  docker exec $containername sh -c "ldapdelete -x -D cn=${ldap_manager},${ldap_basedn} -w ${ldap_pw} ou=Users,${ldap_basedn}"
  docker exec $containername sh -c "\rm -f /etc/openldap/users.ldif /etc/openldap/organisation.ldif" >/dev/null
  # Add posixAccount support
  # See http://www.tldp.org/HOWTO/archived/LDAP-Implementation-HOWTO/schemas.html
  docker exec $containername sh -c 'echo "include /etc/openldap/schema/nis.schema" >> /etc/openldap/slapd.conf'
  # Create initial LDAP entries
  cat > ${servicedatadir}/ldif-init/ppl+domain_init.ldif << EOF
dn: ou=People,${ldap_basedn}
objectClass: organizationalUnit
ou: People

dn: ou=Group,${ldap_basedn}
objectClass: organizationalUnit
ou: Group

dn: cn=users,ou=Group,${ldap_basedn}
objectClass: top
objectClass: posixGroup
gidNumber: 1000
EOF
  # Restart the container to apply the above changes now
  debug -c "done."
  container_stop $containername && container_start $containername 2>/dev/null
  /bin/rm ${servicedatadir}/ldif-init/*_init.ldif 2>/dev/null
else
  if askif "Update the service?" y; then
    container_remove $containername
    . ${BASH_SOURCE[0]}
  fi
  . $servicedir/manage-users.sh
fi

# Start the container if it is not running
container_running $containername || container_start $containername 
