#!/bin/bash
#
# Webit Cloud Services Toolkit - DDNS server
#
# Copyright 2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="DDNS server"
desc="Provides Dynamic DNS services."

# The image file
dockerimage="davd/docker-ddns"

# Set up the container if it does not exists
if ! container_exists $containername; then

  # Check and set default variables
  if [ -z "${secret+x}" ]; then
    secret=`generate_password`
    prefixStrip="y" # strip the path prefix from the URL at the Web proxy
    siport="8080"
    expose_dns="y"
    zone="$wbdomain"
    dnsport=53
  fi

  # Set up a singleton service or an instance of a multi-instance service
  service_setup

  ask secret "API key to change DNS entries" $secret
  remember "$serviceconf" secret

  ask zone "DNS zone to manage" $zone
  remember "$serviceconf" zone

  ask dnsport "DNS server external port (tcp and udp)" $dnsport
  remember "$serviceconf" dnsport

  container_setup "$dockerimage" $containername \
    -v ${servicedatadir}:/var/cache/bind \
    -e SHARED_SECRET=$secret \
    -e ZONE=$zone \
    -e RECORD_TTL=3600 \
    -p ${dnsport}:53 -p ${dnsport}:53/udp \
    $extraparams

fi

# Start the container if it is not running
container_running $containername || container_start $containername
info "DNS server running on ${dnsport}"
info "Management API is at ${surl}"
info "E.g. ${surl}/update?secret=${secret}&domain=ENTRY&addr=IPADDR"
info "Zone files are in ${servicedatadir}"

return 0
