#!/bin/bash
#
# Webit Cloud Services Toolkit - Web site service
# 
# Copyright 2018-2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="PHP Web site"
desc="Web servers with PHP support"
dockerimage="php:8-apache"

# Run a shell command in the container
function container_exec() {
  debug `docker exec $containername bash -c "$*" 2>&1`
}

service_list_instances

if askif "Create/Update $title instances?" y; then
  if [ -z "$apachemods" ]; then
    prefixStrip="n" # don't strip the path prefix from the URL at the Web proxy
    phpext="mbstring pdo pdo_mysql zip gd"
    apachemods="env rewrite"
  fi

  service_setup_instance

  ask phpext "Required PHP extensions" "$phpext"
  remember "$serviceconf" phpext

  ask apachemods "Required Apache modules" "$apachemods"
  remember "$serviceconf" apachemods

  # TODO ask for -e NO_OPCACHE=1 
  container_setup $dockerimage $containername \
    -v ${servicedatadir}/${sname}:/var/www/html

  # Start the container if it is not running
  container_running $containername || container_start $containername

  while ! container_running $containername ; do
    debug "Waiting for $containername to start..."
    sleep 5;
  done

  info "Installing Composer..."
  container_exec apt update
  container_exec apt -y install zip p7zip
  container_exec 'curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer && chmod +x /usr/bin/composer'

  info "Installing extensions (may take long time)..."
  for i in $phpext; do
# See https://stackoverflow.com/questions/53932774/what-do-docker-php-ext-configure-docker-php-ext-install-and-docker-php-ext-enab
    case $i in
    mcrypt)
      container_exec apt -y install libmcrypt-dev
# TODO yes '' | pecl -q install ...
      container_exec pecl install mcrypt
      container_exec docker-php-ext-enable $i
      ;;
    mbstring)
      container_exec apt -y install libonig-dev
      container_exec docker-php-ext-install mbstring
      ;;
    zip)
      container_exec apt -y install libzip-dev
      container_exec docker-php-ext-install zip
      ;;
    gd)
      container_exec apt -y install zlib1g-dev libpng-dev libfreetype6-dev libjpeg62-turbo-dev
      container_exec docker-php-ext-configure gd --with-freetype --with-jpeg
      container_exec docker-php-ext-install gd
      ;;
    yaml)
      container_exec apt -y install libyaml-dev
      container_exec pecl install yaml
      container_exec docker-php-ext-enable $i
      ;;
    *)
      container_exec docker-php-ext-install $i
      ;;
    esac
  done

  info "Enabling Apache modules..."
  container_exec a2enmod $apachemods

  container_stop $containername && container_start $containername

else

  if askif "Update the $title service?" y; then
    container_remove $containername
    . ${BASH_SOURCE[0]}
  fi

fi

return 0
