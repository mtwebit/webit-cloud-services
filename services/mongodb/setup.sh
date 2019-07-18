#!/bin/bash
#
# Webit Cloud Services Toolkit - MongoDB
#
# This is also an example for a multi-instance service
# 
# Copyright 2018-2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="Mongodb"
desc="A NoSQL database server"
dockerimage="mongo"

# singleton now
# service_list_instances $mongodb_instances

if askif "Create/Update $title?" y; then

  if [ -z "$manager" ]; then
    manager="admin"
    manager_pw=`generate_password`
    siport=27017
    webaccess="n"
  fi

  service_setup

  ask manager "Mongo manager username" $manager
  remember "$serviceconf" manager
  ask manager_pw "Mongo manager password" $manager_pw
  remember "$serviceconf" manager_pw

  container_setup "${dockerimage} --config /etc/mongo/mongod.conf" \
    $containername \
    -v ${serviceconfigdir}/${sname}:/etc/mongo \
    -v ${servicedatadir}/${sname}/db:/data/db \
    -e MONGO_INITDB_ROOT_USERNAME=${manager} \
    -e MONGO_INITDB_ROOT_PASSWORD=${manager_pw}

  # Start the container if it is not running
  container_running $containername || container_start $containername

  # Wait for startup
  while ! container_running $containername ; do
    sleep 2;
  done

  # Create an empty config file
  if [ ! -f  ${serviceconfigdir}/${sname}/mongod.conf ]; then
    touch ${serviceconfigdir}/${sname}/mongod.conf
  fi

fi
