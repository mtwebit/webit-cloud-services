#!/bin/bash
#
# Webit Cloud Services Toolkit - Nextcloud storage
#
# Copyright 2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="Cloud Storage"
desc="Enables cloud file sharing between users."

# The image file
dockerimage="nextcloud"

# Variables set by the caller script
# $servicedir: this directory
# $containername: human-readable name of the container
# $serviceconf: config file in the deployment storing variables set by the user

# Execute a Nextcloud occ command in the docker container
# 1:command to execute
function occ() {
  debug `docker exec --user www-data $containername php occ $* 2>&1`
}

# Set up the container if it does not exists
if ! container_exists $containername; then
  if [ -z "${adminuser}" ]; then # set defaults
    adminuser="admin"
    adminpw=`generate_password`
  fi

  prefixStrip="y"
  service_setup

  ask adminuser "Admin user" $adminuser
  remember "$serviceconf" adminuser
  ask adminpw "Admin password" $adminpw
  remember "$serviceconf" adminpw
  container_setup "$dockerimage" $containername \
    -v  ${wbdir}/data/storage:/var/www/html

  # Start the container if it is not running
  container_running $containername || container_start $containername

  pushd "${servicedatadir}" >/dev/null

  if [ ! -f config/config.php ]; then
    debug "Waiting ${title} to start for the first time..."
    # waiting for the config directory to be created
    while [ ! -d config/ ]; do sleep 3; done
    # configure admin password
    info "Finalizing ${title} installation..."
    occ maintenance:install --admin-user ${adminuser} --admin-pass $adminpw
    # TODO hostname
    # TODO skeleton files
    occ config:system:set trusted_domains 2 --value=${wbhost}
    occ config:system:set overwrite.cli.url --value=${surl}
    if [ "$spath" != "/" ] && [ "$spath" != " " ]; then
      occ config:system:set overwritewebroot --value=${spath}
    fi
    # TODO other settings?
    # docker exec --user www-data $wbstorage php occ config:system:set

    # Disable some apps
    debug "Disabling some Nexcloud apps..."
    for i in federation files_versions files_videoplayer files_pdfviewer comments gallery survey_client updatenotification; do
      # debug -c -n "${i}... "
      occ app:disable $i
    done

    # Install additional apps
    # ldapcontacts ldaporg would be good if they would be better
    # tasks mail contacts calendar spreed external
    # discoursesso unsplash flowupload
    debug "Installing additional Nextcloud apps..."
    for i in user_ldap; do
      # debug -c -n "${i}... "
      occ app:install $i
    done

    # Configure LDAP if config exists
    if [ -f "${wbconfigdir}/ldapserver.conf" ]; then
      # read the LDAP settings
      . "${wbconfigdir}/ldapserver.conf"
      info "Configuring LDAP user authentication..."
      occ ldap:create-empty-config
      occ ldap:set-config s01 ldapHost $sname # ldap instance >/dev/null
      occ ldap:set-config s01 ldapPort 389 >/dev/null
      occ ldap:set-config s01 ldapBase ${ldap_basedn} >/dev/null
      occ ldap:set-config s01 ldapAgentName cn=${ldap_manager},${ldap_basedn} >/dev/null
      occ ldap:set-config s01 ldapAgentPassword $ldap_pw >/dev/null
      occ ldap:set-config s01 ldapExpertUsernameAttr uid >/dev/null
      occ 'ldap:set-config s01 ldapLoginFilter (&(|(objectclass=inetOrgPerson))(uid=%uid))' >/dev/null
      occ 'ldap:set-config s01 ldapUserFilter (|(objectclass=inetOrgPerson))' >/dev/null
      occ ldap:set-config s01 ldapUserFilterObjectclass posixAccount >/dev/null
      occ 'ldap:set-config s01 ldapGroupFilter (&(|(objectclass=posixGroup))(|(cn=users)))' >/dev/null
      occ ldap:set-config s01 ldapGroupFilterObjectclass posixGroup >/dev/null
      occ ldap:set-config s01 ldapGidNumber gidNumber >/dev/null
      occ ldap:set-config s01 ldapGroupDisplayName cn >/dev/null
      occ ldap:set-config s01 ldapGroupMemberAssocAttr gidNumber >/dev/null
      # re-read my settings
      . "${serviceconf}"
    fi
  fi
  popd >/dev/null

  if askif "Enable Web-based, shared document editing?" y; then
    container_exists onlyoffice || warning "Don't forget to install the Onlyoffice service."
    occ app:install onlyoffice
  fi
    
else
  info "A storage service named $sname is runnning."
  info "External URL is $surl"
  info "Admin user: $adminuser   password: $adminpw"
  info "OCC command: docker exec --user www-data $containername php occ"
  if askif "Update the service?" y; then
    container_remove $containername
    . ${BASH_SOURCE[0]}
  fi
fi

# Start the container if it is not running
container_running $containername || container_start $containername
