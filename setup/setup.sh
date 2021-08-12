#!/bin/bash
#
# Webit Cloud Services Toolkit - environment setup
#
# Copyright 2018-2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

# default service storage location
wbdir=$(cd ..; pwd)/wbservices

# try to find the location of the service storage
if [ ! -d "$wbdir" ]; then
  for locroot in .. /storage /opt /project; do
    for loc in wbservices services webservices websites web dhmine; do
      if [ -f "${locroot}/${loc}/config/site.conf" ]; then
        wbdir="${locroot}/${loc}"
        break 2
      fi
    done
  done
fi


if [ -f "${wbdir}" ]; then
  echo "Found a previous deployment in ${wbdir}."
fi

ask wbdir "Destination directory" $wbdir

wbconf="${wbdir}/config/site.conf"

if [ -f "${wbconf}" ]; then
  . "${wbconf}"
else
  # Create an initial configuration
  cat <<EOF
-------------------------------------------------------------------------------
This tool should run on a clean (minimal) OS that has docker support.

It will install a set of core containers (Traefik, Watchtower etc.) to create
an environment for deploying various services (Web, DB etc.).

See https://github.com/mtwebit/webit-docker-services/ for more information.
-------------------------------------------------------------------------------
Creating an initial configuration for deploying Webit Cloud Services.
EOF
  [ -d "$wbdir" ] && warning "$wbdir already exists."
  info $wbdir should have at least 30GB of free space.
  info "Also ensure that you have plenty of disk space for docker images and volumes."
  [ `id -u` != 0 ] && warning "Sudo access may be required to install certain services."
  ask wbname "A short name for this installation" $wbname
  wbid=$(echo $wbname | sed 's/ /\./g' | tr '[:upper:]' '[:lower:]')
  dnet=`docker network ls | grep "${wbid} " | cut -d " " -f 1`
  [ "$dnet" != "" ] && fatal "$wbid is in use.  Setup cannot continue."
  ask wbid "Label for service containers" $wbid
  # TODO backup config?
  # \cp -f "${wbconf}" "${wbconf}".bak-`date +%Y%m%d-%H:%M`
  mkdir -p "${wbdir}" || fatal "Could not create $wbdir"
  wbconfigdir="${wbdir}/config"
  wbdatadir="${wbdir}/data"
  wblogdir="${wbdir}/log"
  debug "Setting up config, data and log directories in ${wbdir}..."
  mkdir -p "${wbconfigdir}" "${wbdatadir}" "${wblogdir}"
  chmod 755 "${wbdatadir}" "${wblogdir}"
  wbconf="${wbconfigdir}/site.conf"
  touch "${wbconf}" && chmod 600 "${wbconf}" || exit 1
  wbhost=`hostname`
  info "Enter the _full_ hostname for external Web access."
  info "You can specify additional host and domain names for services later."
  ask wbhost "Hostname" $wbhost
  wbdomain=`domainname -d`
  info "Enter the full domain name for this installation."
  info "It will be used to create an LDAP database later on."
  ask wbdomain "Domain name" $wbdomain
  info "Certain container downloads may require authentication."
  info "The Auths file stores this credentials."
  dockerauths="$HOME/.docker/config.json"
  ask dockerauths "Auths file location" $dockerauths
  wbemail=`id -un`@$wbhost
  info "A valid email address is required to request HTTPS certificates."
  ask wbemail "Admin's email address" $wbemail
  if [ ! -f $dockerauths ]; then
    mkdir "$HOME/.docker/"
    cat > $dockerauths << EOF
{
}
EOF
  fi
  remember "$wbconf" wbdir
  remember "$wbconf" wbconfigdir
  remember "$wbconf" wbdatadir
  remember "$wbconf" wblogdir
  remember "$wbconf" wbname
  remember "$wbconf" wbid
  remember "$wbconf" wbhost
  remember "$wbconf" wbemail
  remember "$wbconf" dockerauths
  remember "$wbconf" wbdomain
  # TODO collect some basic environment stats for development?
  #info "May I send some deployment stats to the developer?"
  #info "They include machine info, distribution and Docker version."
  #askif "Send stats" y && send_dev_stats;
fi

###################################################
# validating / creating the basic service runtime #
###################################################
if [ "$dockernet" == "" ]; then
  dockernet=$wbid
  ask dockernet "Internal network for service containers" $dockernet
  remember "$wbconf" dockernet
fi
dnet=`docker network ls | grep ${dockernet} | cut -d " " -f 1`
if [ "$dnet" == "" ]; then
  debug "Creating an internal network called '$dockernet' for containers."
  docker network create ${dockernet} >/dev/null
fi
