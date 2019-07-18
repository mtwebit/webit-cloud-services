#!/bin/bash

# if LDAP is not configured and LDAP_URI is set the setup LDAP user auth
if [ ! -f /.ldapenabled ] && [ "$LDAP_URI" != "" ]; then
  /sbin/authconfig --enableldap --enableldapauth --ldapserver=$LDAP_URI --ldapbasedn="$LDAP_BASEDN" --enablelocauthorize --kickstart
  # TODO check if it is working
  touch /.ldapenabled
fi

nslcd -d &
yarn start
