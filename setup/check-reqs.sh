#!/bin/bash
#
# Webit Cloud Services Toolkit - checking requirements
#
# Copyright 2018-2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
# 

which docker 2>/dev/null >/dev/null || fatal "Docker is not installed."
docker ps 2>/dev/null >/dev/null || fatal "Docker is not running."

