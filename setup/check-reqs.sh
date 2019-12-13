#!/bin/bash
#
# Webit Cloud Services Toolkit - checking requirements
#
# Copyright 2018-2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

which docker 2>/dev/null >/dev/null || docker_install
docker ps 2>/dev/null >/dev/null || fatal "Docker is not running."
[ `id -u` != 0 ] && [ "`groups | grep '\bdocker\b'`" == "" ] && fatal "You are not member of the Docker group."

