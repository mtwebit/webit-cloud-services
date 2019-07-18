#!/bin/bash
#
# Webit Cloud Services Toolkit - Watchtower service
#
# Copyright 2018 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

title="Watchtower"
desc="Provides automatic container image updates"
dockerimage="v2tec/watchtower"

if ! container_exists $containername; then
  # setting default values
  if [ -z "${watchtower_cron}" ]; then
    watchtower_cron='0 0 4 * * *'
  fi

  service_setup "internal"

  # also store the container name in the global config
  watchtower=$containername
  remember "$wbconf" watchtower

  ask watchtower_cron "Cron schedule (Sec Min Hour Day Month Weekday): " "$watchtower_cron"
  remember "$serviceconf" watchtower_cron
  watchtower_opts="--cleanup --label-enable"
  info 'com.centurylinklabs.watchtower.enable="true" label enables auto-update.'
  container_setup "$dockerimage --schedule '${watchtower_cron}' $watchtower_opts " \
    $containername \
    -v $dockerauths:/config.json \
    -v /var/run/docker.sock:/var/run/docker.sock
else
  if askif "Update the $title service?" y; then
    container_remove $containername
    . ${BASH_SOURCE[0]}
  fi
fi

container_running $containername || container_start $containername 
