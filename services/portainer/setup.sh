#!/bin/bash
#
# Webit Cloud Services Toolkit - Portainer container
#
# Copyright 2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="Portainer"
desc="Web-based management interface to services."
dockerimage="portainer/portainer"

if ! container_exists $containername; then
  if [ -z "$siport" ]; then
    prefixStrip="y" # strip the path prefix from the URL at the Web proxy
    siport="9000"
  fi
  service_setup
  container_setup "$dockerimage " $containername \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ${wbdir}/data/portainer:/data
else
  if askif "Update the service?" y; then
    container_remove $containername
    . ${BASH_SOURCE[0]}
  fi
fi

container_running $containername || container_start $containername 
