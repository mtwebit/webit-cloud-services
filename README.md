## Webit Cloud Services Toolkit (WBcloud)
This is an extensible framework to set up and to maintain a complex system using Docker containers.
It also contains a set of ready-to-use services (e.g. database, Web server, PHP, LDAP, Unix shell, cloud storage etc.).

Features:  
* provides text- and a Web-based GUIs to manage services
* allows to reconfigure the system on-the-fly without rebuilding and restarting unaffected Docker containers
* keeps all you data and configuration files independently from their service containers
* automatically configures the Web proxy according to the actual set of running services (you can specify individual service URLs)
* requests and renews HTTPS certificates automatically
* easy to extend with new dockerized services, even using Dockerfiles
* supports easy backup and migration to a new location

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
The deployment tool will display the URLs where you can access the management and user interfaces of the installed services.

## System management
You can reconfigure your system by running the deployment utility again or via the Web Admin UI.  
To uninstall a service simply remove its container (using "docker rm" or the Web UI).

## Services
* LDAP authentication (used by many other services)
* automatically configured Web proxy (Traefik)
* Autoupdater (Watchtower)
* Cloud Storage (Nextcloud with LDAP auth)
* Web-based office suite (OnlyOffice)
* Remote shell in a Browser (using WeTTy and LDAP auth)
* PHP-enabled Web server
* Databases: Mariadb, MongoDB, Redis
* Search engine: Solr
* Web-based management UI: Portainer
* [more...](https://github.com/mtwebit/webit-cloud-services/tree/master/services)
* Your own service, see the [Hello World example](https://github.com/mtwebit/webit-cloud-services/tree/master/services/hello-world)

## How does it work
Services are installed as Docker containers and they are connected to each other using an internal docker network.  
The framework uses container labels to automatically configure the Web proxy and the autoupdate tool.  
See the [Wiki](https://github.com/mtwebit/webit-cloud-services/wiki) for more details.

## Bugs & Support
The framework has been used in several projects so it is considered fairly stable.  
If you encounter a bug or missing a feature in the framework create an issue or a pull request.  

Services are generally not supported.  
They are tested during their integration and you can expect that common services (like Mariadb, PHP Web, Cloud Storage) will work well, but there is no guarantee.  
