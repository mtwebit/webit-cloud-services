#!/bin/bash
#
# Webit Cloud Services Toolkit - service example
#
# Copyright 2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="Hello World"
desc="A simple service example"

# The image file
dockerimage="nginx:alpine"

# Variables set by the caller script (among others)
# $wbname: the name of the Webit Cloud instance
# $wbid: a short ID of the instance
# $servicedir: this directory
# $servicename: a short name for this service (basename $servicedir)
# $containername: default name of ther container used by this service ${servicename#[0-9]*-}
# $serviceconf: config file in the deployment dir storing variables set by the user
# $serviceconfigdir: config directory dedicated to this service instance
# $servicedatadir: data directory dedicated to this service instance
# $servicelogdir: log directory dedicated to this service instance
# other variables can be found in the global instance config file


# Use this if you use a custom image repo
# docker_auth REPO USER TOKEN

# You can build your own image using a Dockerfile
#if ! image_exists $dockerimage; then
#  image_build hello-world
#fi

# Set up the container if it does not exists
if ! container_exists $containername; then
  # Check and set default variables
  if [ -z "${myconfigvar+x}" ]; then
    myconfigvar="value"
    prefixStrip="y" # strip the path prefix from the URL at the Web proxy
    siport="80"
  fi

  # Set up a singleton service or an instance of a multi-instance service
  service_setup
  # service_setup_instance
  # The following variables store the settings
  # - sname - name of the service (or service instance)
  # - shost - URL hostname
  # - spath - URL path
  # - surl - full service URL
  # - containername
  # - instanceconf (config file only for instances)
  # Traefik settings (they are automatically used)
  # - trule - Traefik frontend rule for the service using PathPrefixStrip method
  # - tlabels - Traefik labels
  # - prefixStrip - use PathPrefixStrip
  # - siport - internal service port

  # Notes on docker parameter settings
  # * restart policy, network, network alias and autoupdate will be set automatically
  # * traefik rules are also set automatically, don't need to specify them
  # * do not publish ports using -p, an internal network is used to reach the container
  # * image params can be added after the $dockerimage variable
  # * map your persistent data storage, config files and logs to the container using -v
  container_setup "$dockerimage" $containername \
    -v ${servicedatadir}:/usr/share/nginx/html:ro
  if [ ! -f "${servicedatadir}/index.html" ]; then
    mkdir -p ${servicedatadir}
    echo "<h1>Hello World!</h1>" > ${servicedatadir}/index.html
  fi
else
  if askif "Update the $title service?" y; then
    container_remove $containername
    . ${BASH_SOURCE[0]}
  fi
fi

# Start the container if it is not running
container_running $containername || container_start $containername

return 0
