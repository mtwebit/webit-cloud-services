#!/bin/bash
#
# Webit Cloud Services Toolkit - Portainer container
#
# Copyright 2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="Apache Solr"
desc="Document indexing and search"

# The image file
dockerimage="solr"

# Set up the container if it does not exists
if ! container_exists $containername; then
  if [ -z "$siport" ]; then
    prefixStrip="n" # do not strip the path prefix from the URL at the Web proxy
    siport="8983"
    webaccess="n"
  fi

  service_setup

  if [ ! -d "${servicedatadir}/data" ]; then
    if [ `id -u` != 0 ]; then
      info "Need superuser privilege to exec chown -R 8983:8983 ${servicedatadir}"
    fi
    sudo chown -R 8983:8983 "${servicedatadir}"
  else
    info "Using already existing data in ${servicedatadir}"
  fi

  container_setup "$dockerimage" $containername \
    -v ${servicedatadir}:/var/solr \
    --env SOLR_HEAP=1024m
else
  if askif "Update the $title service?" y; then
    container_remove $containername
    . ${BASH_SOURCE[0]}
  fi
fi

# Start the container if it is not running
container_running $containername || container_start $containername
