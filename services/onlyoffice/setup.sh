#!/bin/bash
#
# Webit Cloud Services Toolkit - Onlyoffice
#
# Copyright 2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="Onlyoffice"
desc="A Web-based office suite"
dockerimage="onlyoffice/documentserver"

if ! container_exists $containername; then
  # Check and set default variables
  if [ -z "${passwd+x}" ]; then
    passwd=`generate_password`
    prefixStrip="y" # strip the path prefix from the URL at the Web proxy
    siport="80"
  fi

  service_setup
  container_setup "$dockerimage" $containername
else
  if askif "Update the $title service?" y; then
    container_remove $containername
    . ${BASH_SOURCE[0]}
  fi
fi

# Start the container if it is not running
container_running $containername || container_start $containername

return 0
