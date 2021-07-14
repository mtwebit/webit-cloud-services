#!/bin/bash
#
# Webit Cloud Services Toolkit - Keycloak user and access management
#
# Copyright 2021 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="Keycloak"
desc="Identity and Access Management"

# The image file
dockerimage="quay.io/keycloak/keycloak:14.0.0"

# See https://github.com/keycloak/keycloak-containers/tree/master/server

# Variables set by the caller script
# $servicedir: this directory
# $containername: human-readable name of the container
# $serviceconf: config file in the deployment storing variables set by the user

# Set up the container if it does not exists
if ! container_exists $containername; then
  if [ -z "${adminuser}" ]; then # set defaults
    adminuser="admin"
    adminpw=`generate_password`
  fi

  prefixStrip="y"
  siport="8080"
  service_setup

  ask adminuser "Admin user" $adminuser
  remember "$serviceconf" adminuser
  ask adminpw "Admin password" $adminpw
  remember "$serviceconf" adminpw

  params="-e KEYCLOAK_USER=${adminuser} -e KEYCLOAK_PASSWORD=${adminpw} -e KEYCLOAK_FRONTEND_URL=${surl} -e PROXY_ADDRESS_FORWARDING=true"
  params="-e KEYCLOAK_USER=${adminuser} -e KEYCLOAK_PASSWORD=${adminpw} -e PROXY_ADDRESS_FORWARDING=true"

  if askif "Enable MariaDB (MySQL) backend?" y; then
    container_exists mariadb || warning "Don't forget to install the MariaDB service."
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
    ask dbuser "DB user" $dbuser
    remember "$serviceconf" dbuser
    ask dbpw "DB password" $dbpw
    remember "$serviceconf" dbpw
    params="${params} -e DB_ADDR=${dbhost} -e DB_DATABASE=${dbname} -e DB_USER=${dbuser} -e DB_PASSWORD=${dbpw} DB_VENDOR=mariadb"
  else
    # Map the internal database dir to the service data dir
    # TODO this does not work, needs to prepare the dir beforehand
    # params="${params} -v ${servicedatadir}:/opt/jboss/keycloak/standalone/data/"
    warning "Keycloud data will not be stored in a persistent storage."
  fi

echo $params

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
