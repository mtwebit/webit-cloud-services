#!/bin/bash
#
# Webit Cloud Services Toolkit - Web site service
# 
# Copyright 2018-2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="PHP Web site"
desc="Web servers with PHP support"
# very buggy
# dockerimage="richarvey/nginx-php-fpm:latest"
# Maybe this? https://github.com/graze/docker-php-alpine
# buggy iconv and missing ssmtp
dockerimage="boxedcode/alpine-nginx-php-fpm"
# seems to have better iconv and ssmtp
# TODO test this:
#dockerimage="alexmasterov/alpine-php"

# TODO install and use gnu-iconv
# apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted gnu-libiconv
# and reconfigure supervisord
# [program:php-fpm]
# environment=LD_PRELOAD=/usr/lib/preloadable_libiconv.so
# Also add this line to /root/.bashrc
# declare -x LD_PRELOAD="/usr/lib/preloadable_libiconv.so"
# test: php -d error_reporting=22527 -d display_errors=1 -r 'var_dump(iconv("UTF-8", "UTF-8//IGNORE", "This is the Euro symbol '\''€'\''."));'
# test: iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', 'íöüóőúéáűšěýčíéáýřčíšýíščř');
#
# PDF tools
# apk add poppler-utils
#
# TODO install pecl extensions
# apk add --no-cache yaml yaml-dev imagemagick-dev imagemagick libtool autoconf
# pecl install yaml
# pecl install imagick
# echo "extension=yaml.so" >> /usr/etc/php.ini
# echo "extension=imagick.so" >> /usr/etc/php.ini
# echo "extension=yaml.so" > /etc/php.d/yaml.ini
# echo "extension=imagick.so" > /etc/php.d/imagick.ini
# ln -s /usr/lib/php/extensions/no-debug-non-zts-20160303/imagick.so /usr/lib/php/modules/
# ln -s /usr/lib/php/extensions/no-debug-non-zts-20160303/yaml.so /usr/lib/php/modules/

# TODO
# apk add ssmtp
# vi /etc/ssmtp/ssmtp.conf
#   mailhub=
#   rewriteDomain=
#   FromLineOverride=Yes

# TODO
# max_input_vars mérete?
# apk add git

service_list_instances

if askif "Create/Update $title instances?" y; then
  if [ -z "$prefixStrip" ]; then
    prefixStrip="n" # don't strip the path prefix from the URL at the Web proxy
  fi

  service_setup_instance

  if askif "Do you need rsync file access for the website?" n; then
    ask rsync_port "External port number for rsync access to this container? (0=random)" 873
    needrsync=1
    extraparams="-p ${rsync_port}:873 "
    remember "$instanceconf" rsync_port
  else
    needrsync=0
  fi

  # TODO ask for -e NO_OPCACHE=1 
  container_setup $dockerimage $containername \
    -v ${serviceconfigdir}/${sname}:/etc/nginx/conf.d \
    -v ${servicelogdir}/${sname}:/var/log \
    -v ${servicedatadir}/${sname}:/var/www/html/${spath} \
    $extraparams \
    -e NO_OPCACHE=1

  if [ ! -f "${serviceconfigdir}/${sname}/default.conf" ]; then
    info "Creating initial configuration for the Nginx Web server."
    mkdir -p "${serviceconfigdir}/${sname}/"
    cat ${servicedir}/nginx.conf > "${serviceconfigdir}/${sname}/default.conf"
    container_start $containername
    if [ "$spath" == "/" ]; then
      # Remove complex rewire rules if we serve from the root
      # TODO this seems to be buggy
      sed -i "/rewrite.*PATH/d" "${serviceconfigdir}/${sname}/default.conf"
    fi
    # Set try_files rules according to the subpath
    sed -i "s#/PATH#$spath#g" "${serviceconfigdir}/${sname}/default.conf"
    # Set the hostname - not needed atm
    #sed -i "s/HOSTNAME/${shost}/g" "${serviceconfigdir}/${sname}/default.conf"
    # set permissions
    docker exec $containername chown nginx:nginx /var/www/html 2>/dev/null >/dev/null
    docker restart $containername >/dev/null
  fi
  if [ "$needrsync" == "1" ]; then
    # TODO this is not tested
    if [ "docker exec -it ${containername} ls /etc/rsyncd.conf 2> /dev/null" != "/etc/rsyncd.conf" ]; then
    info "Setting up an rsync server to provide file access."
    docker exec $containername sh -c 'timeout 8 apk update' 2>/dev/null >/dev/null
    docker exec $containername sh -c 'timeout 5 apk add --no-cache rsync' 2>/dev/null >/dev/null
    cp ${servicedir}/websites-rsync.conf ${servicedatadir}/${sname}
    docker exec ${containername} sh -c "cat /var/www/html/websites-rsync.conf >> /etc/rsyncd.conf && /bin/rm -f /var/www/html/websites-rsync.conf"
    docker exec ${containername} sh -c "echo 'rsync --daemon -v --log-file /var/log/rsyncd.log' >> /entrypoint.sh"
    if [ ! -f "${serviceconfigdir}/${sname}/rsync_users" ]; then
       ask rsync_user "Rsync remote username" "webadmin"
       remember "$instanceconf" rsync_user
       rsync_password=`generate_password`
       ask rsync_password "User password" $rsync_password
       remember "$instanceconf" rsync_password
       echo "${rsync_user}:${rsync_password}" >> "${serviceconfigdir}/${sname}/rsync_users"
       chmod 600 "${serviceconfigdir}/${sname}/rsync_users"
    fi
    docker restart $containername >/dev/null
    fi
    rsync_port=$(docker inspect -f '{{ (index (index .NetworkSettings.Ports "873/tcp") 0).HostPort }}' $containername)
    info "Remote file access: rsync://${rsync_user}@${shost}:${rsync_port}/webroot"
  fi
  # TODO do we need this?
  # info "Disabling IPv6 in $containername."
  # docker exec $containername sh -c "sed -i 's/\(listen.*\)\[::\]/#\1\[::\]/g' /etc/nginx/conf.d/*.conf"

  # Start the container if it is not running
  container_running $containername || container_start $containername

fi

