#!/bin/bash
#
# Webit Cloud Services Toolkit - LDAP useradd script
#
# Copyright 2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

if [ "$WBROOT" == "" ]; then
  WBROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
  . ${WBROOT}/services/00-setup/functions.sh
  . ${WBROOT}/services/00-setup/setup.sh
fi

ldapconfig="${wbconfigdir}/ldapserver.conf"

if [ ! -f "$ldapconfig" ]; then
  fatal "LDAP is not configured."
fi

. $ldapconfig

info "Current LDAP users in ${containername}:"
docker exec $containername sh -c "ldapsearch -x -b ou=People,${ldap_basedn} | egrep -e '^(uid|mail):'"
ldapuids=$(docker exec $containername sh -c "ldapsearch -x -b ou=People,${ldap_basedn} | grep '^uidNumber: ' | cut -d : -f 2 | sort -n ")

ldapgroups=$(docker exec $containername sh -c "ldapsearch -x -b ou=Group,${ldap_basedn} | egrep -e '^(cn|gidNumber): ' | cut -d : -f 2 | sort -n ")
info "Current LDAP groups:"
echo "$ldapgroups"
ldapgids=$(docker exec $containername sh -c "ldapsearch -x -b ou=Group,${ldap_basedn} | grep '^gidNumber: ' | cut -d : -f 2 | sort -n ")


if askif "Add a new LDAP group?" n; then
  ask new_gname "Short name for the new group"
  # TODO FULL version if ldapsearch -x won't work
  # ldapsearch -H ldaps://${ldapserver} -D "cn=${ldap_manager},${ldap_basedn}" -w ${ldap_pw}
  lastgid=$(docker exec $containername sh -c "ldapsearch -x -b ou=Group,${ldap_basedn} | grep '^gidNumber' | cut -d : -f 2 | sort -n | tail -n 1")
  ask new_gid "Group ID for the new group" $((lastgid + 1))
  cat > ${wbdatadir}/ldapserver/ldif-init/newgroup_init.ldif << EOF
dn: cn=${new_gname},ou=Group,${ldap_basedn}
objectClass: top
objectClass: posixGroup
gidNumber: ${new_gid}
EOF
  info "Restarting '$containername' to initialize the new group."
  docker restart $containername >/dev/null
  # let it process the ldif files
  sleep 3
  /bin/rm ${wbdatadir}/ldapserver/ldif-init/newgroup_init.ldif
  ldapgids=$(docker exec $containername sh -c "ldapsearch -x -b ou=Group,${ldap_basedn} | grep '^gidNumber: ' | cut -d : -f 2 | sort -n ")
fi

if askif "Add a new LDAP user?" n; then
  # TODO quota
  ask new_email "Email address" ""
  ask new_uname "Short username"
  ask new_fullname "Full user name"
  ask new_surname "Surname" $new_fullname[2]
  lastuid=$(docker exec $containername sh -c "ldapsearch -x -b ${ldap_basedn} | grep '^uidNumber' | cut -d : -f 2 | sort -n | tail -n 1")
  if [ "$lastuid" == "" ]; then
    lastuid=999
  fi
  ask new_uid "User ID for the new user" $((lastuid + 1))
  info "Current LDAP group IDs: $ldapgids"
  ask new_gid "Group ID for the new user"
  new_pw=`generate_password`
  ask new_pw "User password" $new_pw
  cat > ${wbdatadir}/ldapserver/ldif-init/newuser_init.ldif << EOF
dn: uid=${new_uname},ou=People,${ldap_basedn}
objectClass: posixAccount
objectClass: inetOrgPerson
uid: ${new_uname}
cn: ${new_fullname}
sn: ${new_surname}
uidNumber: ${new_uid}
gidNumber: ${new_gid}
homeDirectory: /home/${new_uname}
loginShell: /bin/bash
userPassword: $new_pw
mail: $new_email
EOF
  info "Restarting '$containername' to initialize the new user."
  docker restart $containername >/dev/null
  # let it process the ldif files
  sleep 3
  /bin/rm ${wbdatadir}/ldapserver/ldif-init/newuser_init.ldif
fi
