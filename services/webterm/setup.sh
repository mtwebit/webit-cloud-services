#!/bin/bash
#
# Webit Cloud Services Toolkit - Web terminal
#
# Copyright 2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="Unix shell"
desc="A Web-based shell access"

# The image file
dockerimage="webterm"

# build the image if it does not exists
if ! image_exists $dockerimage; then
  image_build webterm
fi

# Set up the container if it does not exists
if ! container_exists $containername; then
  if [ -z "${adminuser}" ]; then
    adminuser="admin"
    adminpw=`generate_password`
    siport=3000
  fi
  # TODO make this configurable in the image
  spath="/wetty"
  remember "${serviceconf}" spath

  service_setup

  if [ -f "${wbconfigdir}/ldapserver.conf" ]; then
    . "${wbconfigdir}/ldapserver.conf"
    extras="--env LDAP_URI='ldap://${sname}' --env LDAP_BASEDN='${ldap_basedn}'"
    # reload my settings
    . "${serviceconf}"
  else
    warning "A working LDAP container is recommended for this service."
    extras=""
  fi

  container_setup "$dockerimage" $containername \
    -v ${servicedatadir}:/home \
    $extras \
    --label "traefik.frontend.passHostHeader=true"

  # Start the container if it is not running
  container_running $containername || container_start $containername

  # Create home dir on first login
  docker exec $containername sh -c 'echo "session     required      pam_mkhomedir.so mask=0022 skel=/etc/skel" >> /etc/pam.d/system-auth-ac'
else
  if askif "Update the $title service?" y; then
    container_remove $containername
    . ${BASH_SOURCE[0]}
  fi
fi
