#!/bin/bash
#
# Webit Cloud Services Toolkit - InfluxDB
#
# Copyright 2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="Influxdb"
desc="A time series database server"
dockerimage="influxdb"

service_list_instances $influxdb_instances

if askif "Create/Update $title instances?" y; then
  webaccess="n"

  [ "$1" != "" ] && sname="$1" && mydb="$1"

  service_setup_instance
  [ -z "$mydb" ] && mydb="$sname"
  [ -z "$adminpw" ] && adminpw=`generate_password`


  if [ ! -d ${servicedatadir}/${sname} ]; then
    ask mydb "Database name" $mydb
    remember "$instanceconf" mydb
    ask adminuser "Admin name" admin
    remember "$instanceconf" adminuser
    ask adminpw "Admin password" $adminpw
    remember "$instanceconf" adminpw
    # TODO enable Graphite?
    # TODO enable external access to the API?
  else
    info "Using databases found in ${servicedatadir}/${sname}"
    info "The admin user and password are ${adminuser}:${adminpw}."
  fi

  info -n "Creating initial InfluxDB config..."
  mkdir -p ${serviceconfigdir}/${sname}/
  docker run --rm ${dockerimage} influxd config > ${serviceconfigdir}/${sname}/influxdb.conf 2>/dev/null || fatal "failed."
  info -c "done."
  info "See ${serviceconfigdir}/${sname}/influxdb.conf"

  info -n "Creating an InfluxDB database and admin user..."
  docker run --rm \
    -e INFLUXDB_DB=${mydb} \
    -e INFLUXDB_ADMIN_ENABLED=true \
    -e INFLUXDB_ADMIN_USER=${adminuser} \
    -e INFLUXDB_ADMIN_PASSWORD=${adminpw} \
    -v ${serviceconfigdir}/${sname}/influxdb.conf:/etc/influxdb/influxdb.conf:ro \
    -v ${servicedatadir}/${sname}:/var/lib/influxdb \
      influxdb /init-influxdb.sh -config /etc/influxdb/influxdb.conf 2>/dev/null >/dev/null || fatal "failed."
  info -c "done."

  container_setup "${dockerimage} -config /etc/influxdb/influxdb.conf" $containername \
    -v ${serviceconfigdir}/${sname}/influxdb.conf:/etc/influxdb/influxdb.conf:ro \
    -v ${servicedatadir}/${sname}:/var/lib/influxdb \
    $extraparams

  info "Starting the service..."
  container_running $containername || container_start $containername || fatal "failed."

  info "Testing the service by listing databases..."
  echo docker run --rm --network ${dockernet} -it ${dockerimage} influx -host ${containername} -execute 'SHOW DATABASES'
  docker run --rm --network ${dockernet} -it ${dockerimage} influx -host ${containername} -execute 'SHOW DATABASES' || fatal "failed."

fi
