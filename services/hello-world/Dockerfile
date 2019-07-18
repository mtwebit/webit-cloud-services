#
# This is an example how to create your own service image
#
# Based on the webterm service
#

#
# Build image
#
FROM centos:centos7
WORKDIR /usr/src
RUN curl -o /etc/yum.repos.d/yarn.repo --silent --location https://dl.yarnpkg.com/rpm/yarn.repo
RUN curl --silent --location https://rpm.nodesource.com/setup_6.x | bash -
RUN yum -y install nodejs yarn git gcc-c++ make && \
    git clone https://github.com/butlerx/wetty && \
    cd wetty && \
    yarn && \
    yarn build && \
    yarn install --production --ignore-scripts --prefer-offline

#
# Run-time image
#
#FROM centos:centos7
MAINTAINER mtwebit

RUN yum -y install bash-completion file man man-pages man-pages-overrides vim-enhanced lftp patch wget && \
    rpm -ivh http://repository.it4i.cz/mirrors/repoforge/redhat/el7/en/x86_64/rpmforge/RPMS/rpmforge-release-0.5.3-1.el7.rf.x86_64.rpm && \
    yum-config-manager --disable rpmforge > /dev/null
RUN yum -y --enablerepo=rpmforge install rar unrar p7zip p7zip-plugins zip unzip
RUN yum -y install nss-pam-ldapd openldap-clients authconfig
#COPY --from=0 /usr/src/wetty /app
RUN cp -pr /usr/src/wetty /app
WORKDIR /app
COPY entrypoint.sh /
RUN chmod 755 /entrypoint.sh

ENV LDAP_URI="ldapserver" \
    LDAP_BASEDN="dc=example,dc=org" \
    NODE_ENV=production

VOLUME ["/home"]

EXPOSE 3000

CMD ["/entrypoint.sh"]
