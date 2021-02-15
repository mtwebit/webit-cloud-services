#!/bin/bash
#
# Webit Cloud Services Toolkit - Shinobi server
#
# Copyright 2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="Shinobi server"
desc="Provides CCTV services."

# The image file
dockerimage="migoller/shinobidocker:microservice"

# Set up the container if it does not exists
if ! container_exists $containername; then

  if [ -z "${dbserver+x}" ]; then
    prefixStrip="n" # strip the path prefix from the URL at the Web proxy
    siport="8080"
    adminuser="admin"
    adminpw=`generate_password`
    dbserver="${wbhost}"
    dbname="shinobi"
    dbuser="shinobi"
    dbpw=""
  fi


  # Set up a singleton service or an instance of a multi-instance service
  service_setup

  ask adminuser "Shinobi admin user" ${adminuser}
  remember "$serviceconf" adminuser
  ask adminpw "Admin password" ${adminpw}
  remember "$serviceconf" adminpw

  warning "Mariadb (MySQL) is required to run Shinobi."
  info "This script can initialize the db if you provide MariaDB admin access"
  ask dbserver "MariaDB host (name of the container instance)" $dbserver
  remember "$serviceconf" dbserver
  ask dbname "DB name" $dbname
  remember "$serviceconf" dbname
  ask dbuser "DB username" $dbuser
  remember "$serviceconf" dbuser
  ask dbpw "DB password" $dbpw
  remember "$serviceconf" dbpw
  if askif "Do you want me to create the DB and the user for you?" y; then
    ask dbadmin "DB admin user" "root"
    ask dbadminpw "DB admin password" ""
    extraparams="-e MYSQL_ROOT_PASSWORD=${dbadminpw} -e MYSQL_ROOT_USER=${dbadmin}"
  else
    $extraparams=""
  fi

  container_setup "$dockerimage" $containername \
    -e ADMIN_USER=${adminuser} \
    -e ADMIN_PASSWORD=${adminpw} \
    -e CRON_KEY=b59b5c62-57d0-4cd1-b068-a55e5222786f \
    -e PLUGINKEY_MOTION=49ad732d-1a4f-4931-8ab8-d74ff56dac57 \
    -e PLUGINKEY_OPENCV=6aa3487d-c613-457e-bba2-1deca10b7f5d \
    -e PLUGINKEY_OPENALPR=SomeOpenALPRkeySoPeopleDontMessWithYourShinobi \
    -e MOTION_HOST=localhost \
    -e MOTION_PORT=8080 \
    -e MYSQL_USER=$dbuser \
    -e MYSQL_PASSWORD=$dbpw \
    -e MYSQL_HOST=$dbserver \
    -e MYSQL_DATABASE=$dbname \
    -v /etc/localtime:/etc/localtime:ro \
    -v /etc/timezone:/etc/timezone:ro \
    -v ${serviceconfigdir}:/config \
    -v ${servicedatadir}:/opt/shinobi/videos \
    -v /dev/shm/shinobiDockerTemp:/dev/shm/streams \
    $extraparams

  warning "Don't forget to change your plugin keys in the config."
  info "See ${serviceconfigdir}"
fi

# Start the container if it is not running
container_running $containername || container_start $containername

return 0
