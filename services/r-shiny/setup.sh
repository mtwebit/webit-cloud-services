#!/bin/bash
#
# Webit Cloud Services Toolkit - R Shiny service
#
# Copyright 2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="R Shiny"
desc="R server + Shiny frontend"

# The image file
dockerimage="rocker/shiny"

# TODO container setup
# apt update && apt install libssl-dev libsasl2-dev tcl-dev tk-dev git vim
# install.packages("stylo")
# install.packages("readr")
# install.packages("mongolite")
# install.packages("shinyBS")
# install.packages("properties")
# cd ...../shiny-server/; git clone ...
# chown -R shiny:shiny /tmp/workspace/ /srv/shiny-server/......
# Set up the container if it does not exists

if ! container_exists $containername; then
  if [ -z "$siport" ]; then
    prefixStrip="n" # do not strip the path prefix from the URL at the Web proxy
    siport="3838"
  fi
  service_setup
  container_setup "$dockerimage" $containername \
    -v ${serviceconfigdir}:/etc/shiny-server \
    -v ${servicedatadir}:/srv/shiny-server \
    -v ${servicelogdir}:/var/log/shiny-server \
    --label "traefik.frontend.passHostHeader=true" \
    --label "traefik.frontend.auth.basic.removeHeader=false" \
    --label "traefik.frontend.auth.headerField=X-WebAuth-User" \
    --label "traefik.frontend.auth.basic.usersFile=/etc/traefik/${containername}.htpasswd"
  if [ ! -s "${serviceconfigdir}/shiny-server.conf" ]; then
    info "Creating a new shiny server config."
    mkdir -p "${serviceconfigdir}"
    cat <<EOF > "${serviceconfigdir}/shiny-server.conf"
# Instruct Shiny Server to run applications as the user "shiny"
run_as shiny;

# Define a server that listens on port 3838
server {
  listen 3838;

  location /rshiny {
    site_dir /srv/shiny-server;
    log_dir /var/log/shiny-server;
    directory_index on;
  }
# Other location example
#  location /rshiny/shtylo {
#    site_dir /srv/shiny-server/shtylo;
#    log_dir /var/log/shiny-server;
#    directory_index off;
#  }
}
EOF
  else
    info "Using already existing shiny server config."
  fi

else
  if askif "Update the $title service?" y; then
    container_remove $containername
    . ${BASH_SOURCE[0]}
  fi
fi

# Start the container if it is not running
container_running $containername || container_start $containername
