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

  prefixStrip="n"
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
    -v /etc/localtime:/etc/localtime:ro \
    -e DISABLE_SSL=TRUE \
    -e PORT=80 \
    -e DB_USER=$dbuser \
    -e DB_PASSWORD=$dbpw \
    -e DB_HOST=$dbserver \
    -e DB_NAME=$dbname

  if [ "$spath" != "/" -a ! -f "${servicedatadir}/config.ini.php" ]; then


    container_running $containername || container_start $containername

    while ! container_running $containername ; do
      debug "Waiting for $containername to start..."
      sleep 5;
    done

    # increase max upload size
    docker exec $containername sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 20M/g' /etc/php/7.2/apache2/php.ini

    # handle suburls by moving the software to the appropriate location
    # TODO handle suburls changes if config.ini.php exists
    docker exec $containername mkdir /var/www/html/.tempfolder
    docker exec $containername mv /var/www/html/\* /var/www/html/.tempfolder
    docker exec $containername mkdir -p /var/www/html/$spath
    docker exec $containername mv /var/www/html/.tempfolder/\* /var/www/html/$spath
    docker exec $containername ln -s /var/www/html/data /var/www/html/$spath/data
    docker exec $containername rmdir /var/www/html/.tempfolder

    # fix permissions
    docker exec $containername chown -R www-data.www-data /var/www/html
  fi
else
  if askif "Update the $title service?" y; then
    container_remove $containername
    . ${BASH_SOURCE[0]}
  fi
fi

# Start the container if it is not running
container_running $containername || container_start $containername
