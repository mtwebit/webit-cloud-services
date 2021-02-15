#!/bin/bash
#
# Webit Cloud Services Toolkit - Webtrees web-based genealogy application
#
# Copyright 2020 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="Genealogy webapp"
desc="An on-line collaborative genealogy application"

# The image file
dockerimage="dtjs48jkt/webtrees"

# Variables set by the caller script
# $servicedir: this directory
# $containername: human-readable name of the container
# $serviceconf: config file in the deployment storing variables set by the user

# Set up the container if it does not exists
if ! container_exists $containername; then
  if [ -z "${dbuser}" ]; then # set defaults
    dbuser="admin"
    dbpw=`generate_password`
    dbserver="${wbhost}"
    dbname="webtrees"
  fi

  prefixStrip="y"
  service_setup

  warning "Mariadb (MySQL) is required to run Webtrees."
  info "This script can initialize the db if you provide MariaDB admin access"
  ask dbserver "MariaDB host (name of the container instance)" $dbserver
  remember "$serviceconf" dbserver
  ask dbname "DB name" $dbname
  remember "$serviceconf" dbname
  ask dbuser "DB username" $dbuser
  remember "$serviceconf" dbuser
  ask dbpw "DB password" $dbpw
  remember "$serviceconf" dbpw

  container_setup "$dockerimage" $containername \
    -v ${servicedatadir}:/var/www/html/data \
    -e DISABLE_SSL=TRUE \
    -v /etc/localtime:/etc/localtime:ro \
    -v /etc/timezone:/etc/timezone:ro \
    -e DB_USER=$dbuser \
    -e DB_PASSWORD=$dbpw \
    -e DB_HOST=$dbserver \
    -e DB_NAME=$dbname
fi

# Start the container if it is not running
container_running $containername || container_start $containername
