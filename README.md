## Webit Cloud Services Toolkit (WBcloud)
This is a framework to set up and to maintain a complex system using Docker containers,
also provides a set of ready-to-use services (e.g. database, Web server, PHP, LDAP, Unix shell etc.)
and a menu-driven tool to simplify system installation and maintenance.

Features:  
* reconfigure the system on-the-fly without rebuilding and restarting everything
* keeps all you data and configuration files independently from their service containers
* an automatically configured proxy gateway connects your services to the Web (you can specify service URLs)
* it also requests and renews HTTPS certificates automatically
* containers can be auto-updated periodically
* easy to extend with new dockerized services, even using Dockerfiles
* a GUI to manage containers over the Web
* easy backup and migration to a new location

## Installation
[Install Docker](https://docs.docker.com/install/).  
Get the source and start the deplopment utility:  
```sh
git clone https://github.com/mtwebit/webit-cloud-services.git  
cd webit-cloud-services  
./wbsetup.sh
```
Select a target directory where service configuration and data files will be stored,
specify a few settings for your system and let the installer do the magic.  
The deployment tool will display you the URLs where you can access the management and user interfaces of the installed services.

## System management
You can reconfigure your system by running the deployment utility again or via using the Admin Web UI.  
To uninstall a service simply remove its container (using "docker rm" or the Admin Web UI).

## Services
* LDAP authentication (used by many other services)
* Web proxy (Traefik)
* Autoupdater (Watchtower)
* Cloud Storage (Nextcloud with LDAP auth)
* Remote shell in a Browser (using WeTTy and LDAP auth)
* PHP-based Web server
* Databases: Mariadb, MongoDB
* Management Web UI: Portainer
* [more...](https://github.com/mtwebit/webit-cloud-services/tree/master/services)
* Your own service, see the [Hello World example](https://github.com/mtwebit/webit-cloud-services/tree/master/services/hello-world)

## How does it work
Services are installed as Docker containers and they are connected to each other using an internal docker network.  
The framework uses container labels to configure the Web proxy and the autoupdate tool.  

## Bugs & Support
The framework has been used in several projects so it is considered fairly stable.  
If you encounter a bug or missing a feature in the framework create an issue or pull request.  

Services are generally not supported.  
They are tested during their integration and you can expect that common services (like Mariadb, PHP Web, Cloud Storage)
will work well, but there is no guarantee.
