#!/bin/bash
#
# Webit Cloud Services Toolkit - MariaDB
#
# This is also an example for a multi-instance service
# 
# Copyright 2018-2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="Mariadb"
desc="A MySQL-compatible database server"

case `arch` in
x86_64)
  dockerimage="mariadb"
  ;;
armv7l)
  warning "Using an unofficial MariDB image for ARMv7"
  dockerimage="jsurf/rpi-mariadb"
  ;;
*)
  error "Unsupported host architecture"
  return 0
  ;;
esac

service_list_instances $mariadb_instances

if askif "Create/Update $title instances?" y; then
  webaccess="n"

  if [ -z "$mydb" ]; then
    mydb="$sname"
  fi

  [ "$1" != "" ] && sname="$1" && mydb="$1"

  service_setup_instance

  if [ ! -d ${servicedatadir}/${sname} ]; then
    ask mydb "Database name" $mydb
    remember "$instanceconf" mydb
    ask rootpw "Root password" `generate_password`
    remember "$instanceconf" rootpw
    dboptions="--character-set-server=utf8 --collation-server=utf8_unicode_ci"
    ask dboptions "DB options" "$dboptions"
    remember "$instanceconf" dboptions
    extraparams="-e MYSQL_ROOT_PASSWORD=${rootpw} -e MYSQL_DATABASE=${mydb}"
  else
    info "Using databases found in ${servicedatadir}/${sname}"
    info "The MySQL root password is '${rootpw}'."
    extraparams=""
  fi

  container_setup "${dockerimage} ${dboptions}" $containername \
    -v ${serviceconfigdir}/${sname}:/etc/mysql/conf.d \
    -v ${servicedatadir}/${sname}:/var/lib/mysql \
    $extraparams

  # Start the container if it is not running
  container_running $containername || container_start $containername

  # TODO backup the db periodically
  # $ docker exec some-mysql sh -c 'exec mysqldump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD"' > /some/path/on/your/host/all-databases.sql

fi
