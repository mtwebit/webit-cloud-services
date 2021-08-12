#!/bin/bash
#
# Webit Cloud Services Toolkit - checking requirements
#
# Copyright 2018-2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

which docker 2>/dev/null >/dev/null || docker_install
which curl 2>/dev/null >/dev/null || fatal "Install curl and try again."
which whiptail 2>/dev/null >/dev/null || fatal "Install whiptail (newt) and try again."
[ `id -u` != 0 ] && [ "`groups | grep '\bdocker\b'`" == "" ] && fatal "You are not member of the Docker group."
docker ps 2>/dev/null >/dev/null || fatal "Docker is not running."

