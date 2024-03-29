#!/bin/bash
#
# Webit Cloud Services Toolkit - Keycloak user and access management
#
# Copyright 2021 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 
# See https://github.com/keycloak/keycloak-containers/tree/master/server

title="Keycloak"
desc="Identity and Access Management"

# The image file
dockerimage="quay.io/keycloak/keycloak"
#dockerimage="jboss/keycloak"


# Variables set by the caller script
# $servicedir: this directory
# $containername: human-readable name of the container
# $serviceconf: config file in the deployment storing variables set by the user

# Set up the container if it does not exists
if ! container_exists $containername; then
  if [ -z "${adminuser}" ]; then # set defaults
    adminuser="admin"
    adminpw=`generate_password`
    prefixStrip="n"
    spath="/auth"
  fi

  siport="8080"

  info "Keycloud works with / or /auth URL paths with no prefix strip."

  service_setup

  ask adminuser "Admin user" $adminuser
  remember "$serviceconf" adminuser
  ask adminpw "Admin password" $adminpw
  remember "$serviceconf" adminpw
  params="-e KEYCLOAK_USER=${adminuser} -e KEYCLOAK_PASSWORD=${adminpw}"

  # TODO
  # Szoftvertelepites microdnf segitsegevel
  # docker exec -it -u root keycloak microdnf install vi wget less findutils

  # standalone-ha.xml a default konfig

  # JAVA_OPTS_APPEND is van

  params="${params} -e PROXY_ADDRESS_FORWARDING=true -e KEYCLOAK_FRONTEND_URL=${surl}"

  # Map password-blacklists dir
  params="${params} -v ${servicedatadir}/password-blacklists/:/opt/jboss/keycloak/standalone/data//password-blacklists/"
  if [ ! -d "${servicedatadir}/password-blacklists/" ]; then
    mkdir -p "${servicedatadir}/password-blacklists/"
    info "You may store password blacklists (e.g. 10_million_password_list_top_1000000.txt) in"
    info "   ${servicedatadir}/password-blacklists/"
  fi

  # Map Java truststore and client keys
  params="${params} -v ${servicedatadir}/keystores/:/opt/jboss/keycloak/standalone/configuration/keystores/"
  if [ ! -d "${servicedatadir}/keystores/" ]; then
    mkdir -p "${servicedatadir}/keystores/"
    info "You may store certficite files and Java truststore in"
    info "   ${servicedatadir}/keystores/"
    info "Use keytool -import -alias ALIAS -keystore truststore.jks -file cert.cer"
    info "and modify standalone-ha.xml to enable it."
    info "See https://www.keycloak.org/docs/latest/server_installation/#_truststore"
  fi

  if askif "Enable MariaDB (MySQL) backend?" y; then
    image_exists mariadb || warning "Don't forget to install the MariaDB service."
    if [ -z "${dbhost}" ]; then # set defaults
      dbhost=${containername}-mariadb
      dbuser=keycloak
      dbpw=${adminpw}
      dbname=keycloak
    fi
    ask dbhost "Database host" $dbhost
    remember "$serviceconf" dbhost
    ask dbname "Database name" $dbname
    remember "$serviceconf" dbname
    warning "Ensure that this database exists before continuing."
    ask dbuser "DB user" $dbuser
    remember "$serviceconf" dbuser
    ask dbpw "DB password" $dbpw
    remember "$serviceconf" dbpw
    warning "Keycloak + MySQL startup can take a very long time (20min++)."
# Fix from https://keycloak.discourse.group/t/keycloak-timeout-issue/2309
    params="${params} -e DB_ADDR=${dbhost} -e DB_DATABASE=${dbname} -e DB_USER=${dbuser} -e DB_PASSWORD=${dbpw} -e DB_VENDOR=mariadb -e JAVA_OPTS='-Djboss.as.management.blocking.timeout=3600' -v ${WBROOT}/${servicedir}/mysql-timeout-fix.cli:/opt/jboss/startup-scripts/mysql-timeout-fix.cli"
  else
    # Map the internal database dir to the service data dir
    # TODO this does not work, needs to prepare the dir beforehand
    # params="${params} -v ${servicedatadir}:/opt/jboss/keycloak/standalone/data/"
    warning "Keycloud data will not be stored in a persistent storage."
  fi

  container_setup "$dockerimage" $containername $params

  # Start the container if it is not running
  container_running $containername || container_start $containername

else
  info "A service named $sname is runnning."
  info "External URL is $surl"
  info "Admin user: $adminuser   password: $adminpw"
  if askif "Update the service?" y; then
    container_remove $containername
    . ${BASH_SOURCE[0]}
  fi
fi

# Start the container if it is not running
container_running $containername || container_start $containername
