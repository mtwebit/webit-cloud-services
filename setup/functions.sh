#!/bin/bash
#
# Webit Cloud Services Toolkit - common functions
#
# Copyright 2018-2019 Tamas Meszaros <mt+git@webit.hu>
# Licensed under Mozilla Public License v2.0 http://mozilla.org/MPL/2.0/
#

# Ask a question and provide a default answer
# Sets the variable to the answer or the default value
# 1:varname 2:question 3:default value
function ask() {
  echo -n ">> ${2}: [$3] "
  read pp
  if [ -z "$pp" ]; then
    export ${1}="${3}"
  else
    export ${1}="${pp}"
  fi
}

# Ask a yes/no question, returns true on answering y
# 1:question 2:default answer
function askif() {
  ask ypp "$1" "$2"
  [ "$ypp" == "y" ]
}

# Display a message if verbose option is set
# debug -n ... displays the text without lf
# debug -c ... continues a -n line
function debug() {
  if [ ! -z "$verbose" ]; then
    if [ "$1" == "-n" ]; then
      shift
      echo -en "[\e[94mDEBUG\e[0m] $*"
    else
      if [ "$1" == "-c" ]; then
        shift
        echo $*
      else
        echo -e "[\e[94mDEBUG\e[0m] $*"
      fi
    fi
  fi
}

# Display a message if verbose option is set
function info() {
  if [ "$1" == "-n" ]; then
    shift
    echo -en "[\e[96mINFO\e[0m] $*"
  else
    if [ "$1" == "-c" ]; then
      shift
      echo $*
    else
      echo -e "[\e[96mINFO\e[0m] $*"
    fi
  fi
}

# Display a warning message
function warning {
  echo -e "[\e[93mWARNING\e[0m] $*"
  sleep 2 # let the user notice the warning
}

# Display an error message
function error {
  echo -e "[\e[91mERROR\e[0m] $*"
  sleep 2 # let the user notice the error
}

# Display an error message and exit with error
function fatal {
  error "$*"
  exit 2
}

# Add or update a variable in a config file
# 1: filename 2: variable name
function remember() {
  set -o noglob
  [ ! -f "$1" ] && touch "$1" || sed -i "/^$2=.*$/d" "$1"
  echo ${2}=\'${!2}\' >> "$1"
  set +o noglob
}

# Auth and store Docker credentials
# 1: site
# 2: email/token
# 3: pass
function docker_auth() {
  docker login $1 -u $2 -p $3
}

function docker_install() {
  error "Docker is not installed."
  if askif "Do you wan't to install it?" y; then
    info "Executing curl -fsSL get.docker.com | sh ..."
    curl -fsSL get.docker.com | sh || fatal "Installation failed."
    which docker 2>/dev/null >/dev/null || fatal "Installation failed."
    if [ `id -u` != 0 ]; then
      info "The current user has to be added to the docker group."
      warning "Invoking sudo usermod -aG docker `whoami`"
      sudo usermod -aG docker `whoami`
      warning "You have to log out and back in for this to take effect!"
      exit
    fi
  else
    exit
  fi
}

# Print container names that are based on a given image
# 1: container image name
function container_get_name() {
  docker ps -aq --filter "ancestor=$1" --format "{{.Names}}"
}

# Query a Docker image by its full label
# 1: image label
function image_exists() {
  # TODO does not work status=$(docker image ls -q --filter "label=$1")
  status=$(docker images -q $1)
  [ "$status" != "" ]
}

# Build a Docker image using a Dockerfile
# 1: image label
function image_build() {
  info "Building the $title image. This will take some time..."
  pushd "${servicedir}" >/dev/null
  docker image build --tag "$*" --label "$*" . || fatal "Failed to create the image."
  popd >/dev/null
}

# Query a Docker container by its full name
# 1: container name
function container_exists() {
  status=$(docker ps -aq --filter "name=^/$1\$")
  [ "$status" != "" ]
}

# Check whether a service is running or not
# $1: service name
function container_running() {
  status=$(docker inspect --format "{{.State.Status}}" $1 2>&1)
  [ "$status" == "running" ]
}

# Set up a new docker container
# $1: container image with optional create options
# $2: container name
# The rest: additional docker create arguments 
# Also uses variables set by service_setup like $tlabels
function container_setup() {
  set -o noglob
  dimagefull="$(echo $1 | tr "\n" " ")"
  dimagearray=( $1 )
  dimage="${dimagearray[0]}"
  shift
  dcontainer="$1"
  shift
  ask rpolicy "Restart policy for this service" "unless-stopped"
# TODO do we need the network alias? probably causes problems with real DNS entries
  dargs=" --restart=$rpolicy --network ${dockernet} --network-alias ${containername}.${dockernet} ${tlabels}"
  if askif "Enable automatic updates using Watchtower?" n; then
    dargs="$dargs --label com.centurylinklabs.watchtower.enable=true"
  fi
  info -n "Getting image (may take time)..."
  # TODO pull -q when it will be supported
  # do not exit as we may have the image locally
  # docker pull $dimage 2>&1 > /dev/null || exit 1
  # Need a subshell to supress all messages
  ( docker pull ${dimage} 2>&1 ) >/dev/null
  info -c -n "installing..."
  # a simple docker create ... won't work because of the dimagefull parameter completition
# debug docker create --name $dcontainer --label $wbid $dargs "$@" ${dimagefull} 
  echo docker create --name $dcontainer --label $wbid $dargs "$@" ${dimagefull} | bash 2>&1 > /dev/null || fatal "Failed to create the container"
  info -c "done."
  set +o noglob
}

# Start a service (a container)
# $1: container name
function container_start() {
  debug -n "Starting $1..."
  docker start $1 > /dev/null || fatal "failed."
  # let the container settle
  sleep 3
  debug -c "done."
}

# Stop a service (a container)
# $1: container name
function container_stop() {
  debug -n "Stopping $1..."
  docker stop $1 > /dev/null || fatal "failed."
  debug -c "done."
}

# Print out a service status
# $1: container name
function container_status() {
  echo -n `docker inspect --format "{{.State.Status}}" $1 2>&1`
}

# Print out additional details about a service container
# $1: service name
function container_labels() {
  [ "`docker inspect --format '{{index .Config.Labels "traefik.enable"}}' $1 2>&1`" == "true" ] && echo -n "Frontend "
  [ "`docker inspect --format '{{index .Config.Labels "com.centurylinklabs.watchtower.enable"}}' $1 2>&1`" == "true" ] && echo -n "Autoupdate "
}


# Remove an already existing docker container
# $1 container name
function container_remove() {
  debug -n "Removing ${1} container..."
  docker stop $1 >/dev/null && docker rm $1 >/dev/null || fatal "Failed."
  debug -c "OK"
}

# Get the names of service containers
# $1 status (running, exited, dead etc.)
# See https://docs.docker.com/engine/reference/commandline/ps/
function services_list {
  if [ -z "$1" ]; then
    docker ps -aq --filter "label=$wbid" --format "{{.Names}}"
  else
    docker ps -aq --filter "label=$wbid" --filter "status=$1" --format "{{.Names}}"
  fi
}

function services_print {
  info "Installed services"
  srvid=1
  for s in `services_list`; do
    echo -n "  ${s}"
    case `container_status $s` in
    running)
      echo -en " \e[92mrunning \e[0m"
      ;;
    failed)
      echo -en " \e[91mfailed \e[0m"
      ;;
    exited)
      echo -en " \e[96mexited \e[0m"
      ;;
    *)
      ;;
    esac
    container_labels $s
    echo ""
  done
}

# Build a service menu and perform actions on its items
function services_menu {
  debug -n "Scanning available services..."
  menu=""
  wbservices=$(cd ${WBROOT}; ls */*/setup.sh | sort -t/ -k2)
  for s in $wbservices; do
    #simage=$(grep ^dockerimage ${WBROOT}/$s | cut -d '"' -f 2)
    stitle=$(grep ^title ${WBROOT}/$s | cut -d '"' -f 2)
    sdesc=$(grep ^desc ${WBROOT}/$s | cut -d '"' -f 2)
    #if [ "$simage" == "" ]; then continue; fi
    # TODO require labels
    cname=$(container_get_name $simage)
    if [ "$cname" == "" ]; then
      menu="$menu '$stitle' '$sdesc'"
    else
      menu="$menu '$stitle (`container_status $cname`)' '$sdesc'"
    fi
  done
  if [ "$menu" == "" ]; then
    fatal "No services found."
  fi
  debug -c "done."

  ans=$(echo whiptail --fb --ok-button '"Install / Manage"' --cancel-button '"Exit"' --title \"$wbname\" --menu '"Choose a service to install/upgrade"' 22 78 12 $menu "3>&1 1>&2 2>&3" | sh)
  if [ "$?" == "0" ]; then
    ans=${ans%[ ](*}
    service=$(egrep "^title=\"$ans\"" $wbservices | cut -d : -f 1 )
    service=$(dirname $service) # strip /setup.sh
    if [ "$service" == "" ]; then
      fatal "Internal error finding service file for $ans."
    fi
    services_install $service
  else
    return 1
  fi
}

# Install a service
# $1: full path to a service install script or service name in WBROOT/services
function services_install {
  if [ "$1" == "" ]; then
    fatal "Internal error: No service specified."
  fi
  servicedir=${1}
  # Try to add the default base dir is it is not specified
  if [ ! -d "${servicedir}" ]; then
    servicedir="services/$servicedir"
  fi
  installfile="${servicedir}/setup.sh"

  [ ! -f "$installfile" ] && fatal "Service $1 not found."

  # last dir name
  servicename=$(basename $servicedir)

  # default container name
  containername=$servicename

  # strips special chars from the name
  servicename=${servicename#[0-9]*-}

  # service config file and dedicated directories
  serviceconf="${wbconfigdir}/${servicename}.conf"
  serviceconfigdir="${wbconfigdir}/${servicename}"
  # do not create it here
  # [ ! -d "${serviceconfigdir}" ] && mkdir -p "${serviceconfigdir}"
  servicedatadir="${wbdatadir}/${containername}"
  [ ! -d "${servicedatadir}" ] && mkdir -p "${servicedatadir}"
  servicelogdir="${wblogdir}/${containername}"
  [ ! -d "${servicelogdir}" ] && mkdir -p "${servicelogdir}"

  # read the configuration
  if [ -f "$serviceconf" ]; then
    . "$serviceconf"
  fi

  # Running the install script in a subshell (to forget all its local vars)
  shift
  ( . "$installfile" $* )

  # forget variables set by this script
  unset sname surl spath siport iurl prefixStrip

  # Re-read the global config (might be changed by the service installer)
  . "$wbconf"
}

# Set up a singleton service (only one instance is allowed or used)
# if arg1 is set to internal then no external Web access is allowed
function service_setup {
  [ -z "$sname" ] && sname=$servicename
  ask sname "One word name for the $title container" $sname
  containername=$sname
  while container_exists $containername ; do
    warning "A service named $sname already exists."
    docker ps -aq --filter "name=^/${containername}\$"
    ask sname "Short name for the $title container" $sname
    containername=$sname
  done
  remember "$serviceconf" sname
  [ -z "${webaccess}" ] && webaccess="y"
  [ -z "$tlabels" ] && tlabels="--label traefik.backend=$sname"
  if [ "$1" != "internal" ] && askif "Allow Web access to the service" $webaccess; then
    service_setup_url
    remember "$serviceconf" shost
    remember "$serviceconf" spath
    remember "$serviceconf" surl
    remember "$serviceconf" siport
    remember "$serviceconf" prefixStrip
  fi
}

# Setup a service instance (for services with multiple instances allowed)
function service_setup_instance {
  [ -z "$sname" ] && sname=$servicename
  ask sname "One word name for the $title instance" $sname
  containername=${sname}-${servicename}
  [ ! -d "${serviceconfigdir}" ] && mkdir -p "${serviceconfigdir}"
  while container_exists $containername || [ -d "${servicedatadir}/${sname}" ]; do
    warning "An instance named $sname already exists."
    docker ps -aq --filter "name=^/${containername}\$"
    ls -ld "${servicedatadir}/${sname}"
    info "If you made no changes to the container it is safe to reinstall."
    info "Existing data and configuration are preserved."
    if askif "Do you want to reinstall it?" n; then
      container_exists $containername && container_remove ${containername}
      break;
    fi
    ask sname "One word name for the $title instance" $sname
    containername=${sname}-${servicename}
  done
  # Each instance has its own configuration file
  instanceconf=${serviceconfigdir}/${sname}.conf
  # remember the (updated) instance name in its config file
  remember "$instanceconf" sname
  # and load other settings
  if [ -f "$instanceconf" ]; then
    . "$instanceconf"
  fi
  [ -z "${webaccess}" ] && webaccess="y"
  [ -z "$tlabels" ] && tlabels="--label traefik.backend=${servicename}:${sname}"
  if [ "$1" != "internal" ] && askif "Allow Web access to the service" $webaccess; then
    service_setup_url
    remember "$instanceconf" shost
    remember "$instanceconf" spath
    remember "$instanceconf" surl
    remember "$instanceconf" siport
    remember "$instanceconf" prefixStrip
  fi
}

# Set up an URL for the service (or instance)
function service_setup_url {
  [ "$shost" == "" ] && shost=$wbhost
  ask shost "Hostname (first part of the URL)" "$shost"
  [ "$siport" == "" ] && siport=80
  ask siport "Internal service port number" "$siport"
  # [ "$spath" == "" ] && spath="/${sname}/"	- fix for storage
  [ "$spath" == "" ] && spath="/${sname}"
  ask spath "URL path (starts with /, / = root)" "$spath"
  [ "$prefixStrip" == "" ] && prefixStrip="n"
  if [ "$spath" == "/" ] || [ "$spath" == " " ]; then
    spath="/"
    trule="Host:${shost}"
  else
    if askif "Strip the path prefix at the Web proxy?" $prefixStrip; then
      trule="Host:${shost}\;PathPrefixStrip:${spath}"
      prefixStrip="y"
    else
      trule="Host:${shost}\;PathPrefix:${spath}"
    fi
  fi
  surl="https://${shost}${spath}"
  ask trule "Frontend rule" $trule
  tlabels="$tlabels --label traefik.frontend.rule=${trule} --label traefik.port=$siport --label traefik.enable=true --label traefik.frontend.passHostHeader=true"
  info "External $title URL: ${surl}"
  if [ "$siport" != "80" ] && [ "$siport" != "443" ]; then
    iurl="https://${containername}.${dockernet}:${siport}"
  else
    iurl="https://${containername}.${dockernet}"
  fi
  [ "$prefixStrip" == "y" ] && iurl="${iurl}/" || iurl="${iurl}${spath}"
  info "Internal $title URL: $iurl"
}

# List service instances
function service_list_instances {
  if [ -d "$serviceconfigdir" ]; then
    service_instances=$(cd $serviceconfigdir; ls -d */ 2>/dev/null | sed 's#/##' 2>/dev/null)
  fi
  if [ -z "$service_instances" ]; then
    info "No active $title instances found."
  else
    info "Active $title instances:"
    for i in $service_instances; do
      info -n "Instance '$i': "
      container_running ${i}-${servicename} && container_status ${i}-${servicename} || echo -n "Not running."
      echo ""
      #docker inspect --format "{{.Name}} {{.State.Status}}" ${i}-${servicename} 2>&1
    done
  fi
}


# Install a profile (several services)
# 1: profile file
function profile_install {
  # found=$(cd "$WBROOT"; ls -d profiles/$1 */${1}.wbprofile 2>/dev/null | sed 's#.*/##' 2>/dev/null)
  found=$(cd "$WBROOT"; ls -d profiles/$1 */${1}.wbprofile 2>/dev/null)
  if [ -z "$found" ]; then
    fatal "No profile named $1 found."
  else
    tmpfile=install_temp.$$
    grep -v "^#" $found | while IFS= read -r srv; do
      echo info "Installing $srv" >>$tmpfile
      echo services_install $srv >>$tmpfile
    done
    trap profile_install_cleanup SIGINT
    source $tmpfile
    \rm $tmpfile
    trap - SIGINT
  fi
  exit
}

function profile_install_cleanup {
  rm install_temp.$$
  exit
}

function generate_password {
  < /dev/urandom tr -dc A-Za-z0-9@_+- | head -c${1:-8};echo
}

function encode_htpasswd {
  openssl passwd -apr1 $1
}
