#!/bin/bash
#
# WebIT Cloud Services Toolkit - main deployment utility
#
# Copyright 2018-2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
#

echo "======= WebIT Cloud Services Toolkit deployment tool =========================="

WBROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$1" == "-d" ]; then verbose=true; shift; fi

# Import common functions
. ${WBROOT}/setup/functions.sh

# Check requirements
. ${WBROOT}/setup/check-reqs.sh

# Check / create the setup and read environment variables
. ${WBROOT}/setup/setup.sh

# These are mandatory services, setup them if they are not running:
# Watchtower, Traefik
container_running $watchtower || services_install watchtower
container_running $traefik || services_install traefik

# Install a service profile (several containers at once)
if [ "$1" == "-p" ]; then
  profile_install "$2"
fi

while true; do
  services_menu
  if [ "$?" != "0" ]; then
    break;
  fi
done
