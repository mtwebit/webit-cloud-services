#!/bin/bash
#
# Webit Cloud Services Toolkit - Traefik Web procy service
#
# Copyright 2018 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="Web Proxy"
desc="Web gateway to all backend services."
dockerimage="traefik:v1.7"

if ! container_exists $containername; then
  if [ -z "$siport" ]; then
    prefixStrip="y" # strip the path prefix from the URL at the Web proxy
    siport="9443"
  fi

  service_setup

  # also store the container name in the global config
  traefik=$containername
  remember "$wbconf" traefik

  # setting default values
  if [ "$certfile" == "" ]; then
    certfile="${wbdir}/config/certs/acme.json"
    remember "$serviceconf" certfile
  fi

  if [ ! -f "$certfile" ]; then
    info "Creating $certfile to store certificates."
    mkdir -p "${wbdir}/config/certs/"
    touch "${certfile}"
    chmod 600 "${certfile}"
  else
    info "Using existing certs in ${certfile}."
  fi

  # https://docs.traefik.io/#docker
  # https://docs.traefik.io/user-guide/docker-and-lets-encrypt/
  # We set up Traefik to proxy its own dashboard on port 9443
    #--label "traefik.port=9443" \
    #--label "traefik.frontend.entryPoints=https" \
    #--label "traefik.frontend.redirect.entryPoint=https" \
  # TODO https://remote-lab.net/wordpress-docker-traefik
  container_setup "$dockerimage --docker" $containername \
    --label "traefik.frontend.priority=-100" \
    --label "traefik.protocol=https" \
    -p 80:80 -p 443:443 \
    -v ${serviceconfigdir}:/etc/traefik/ \
    -v ${wbconfigdir}/certs/acme.json:/acme.json \
    -v ${servicelogdir}:/var/log \
    -v /var/run/docker.sock:/var/run/docker.sock

  # Backup the OLD config file if it is not empty
  if [ -s "${serviceconfigdir}/traefik.toml" ]; then
    info "Creating a backup of the old proxy config file."
    trbackup="${serviceconfigdir}/traefik.toml.bak-`date +%Y%m%d-%H:%M`"
    cp "${serviceconfigdir}/traefik.toml" "$trbackup"
    info "Traefik will create and use a fresh config file. You can review the changes:"
    info "diff ${serviceconfigdir}/traefik.toml" "$trbackup"
  else
    mkdir "${serviceconfigdir}"
  fi
  cat ${servicedir}/traefik.toml > "${serviceconfigdir}/traefik.toml"
  # Start Traefik to create its initial config
  #debug "Starting $title to initialize its configuration."
  #container_start $containername
  # Modify the config and restart Traefik
  # sed -i "s/HOSTNAME/${wbhost}/g" "${serviceconfigdir}/traefik.toml"
  sed -i "s/DOMAINNAME/${wbdomain}/g" "${serviceconfigdir}/traefik.toml"
  sed -i "s/EMAIL/${wbemail}/g" "${serviceconfigdir}/traefik.toml"
  #debug "Updating configuration and restarting $title."
  #container_stop $containername
  warning "Certificate requests are disabled."
  warning "To enable it edit ${serviceconfigdir}/traefik.toml."
  # TODO Check and configure the firewall
  warning "If you can't connect to the Traefik status panel, check the firewall."
  warning "E.g. firewall-cmd --zone=public --permanent --add-port 443/tcp"

else
  if askif "Update the $title service?" y; then
    container_remove $containername
    . ${BASH_SOURCE[0]}
  fi
fi

container_running $containername || container_start $containername 
