FROM fedora:29

LABEL maintainer="kaz@praqma.net heh@praqma.net"


# Why Fedora as base OS?
# * Fedora always has latest packages compared to CentOS.
# * Fedora does not need extra CentOS's EPEL repositories to install tools.

# **Note:** Fedora runs as 'root', and has '/' as it's default WORKDIR.

# This Dockerfile builds a container image for Atlassian Confluence, using 
#   atlassian-confluence-*.bin installer. The advantage of using the bin-installer is
#   that it includes OracleJDK (now AdoptJRE). We do not have to depend on Oracle Java 
#   or manage it in our image. Big relief!
#
# Since this container image contains OracleJDK, we can not (re)distribute it 
#   as binary image, because of licensing issues. Though mentioning it in 
#   Dockerfile is ok.
#

# Note: Check build-instructions.md for building this image.

####################################### START -  Environment variables #######################################
#
#

# CONFLUENCE_VERSION:
# ------------------
# The value for CONFLUENCE_VERSION should be a version number, which is part of the name of the confluence software bin/tarball/zip.
ENV CONFLUENCE_VERSION 6.15.4

# OS_USERNAME:
# -----------
#  Confluence bin-installer automatically creates a 'confluence' user and a 'confluence' group. Just specify what it's name is.
ENV OS_USERNAME confluence

# OS_GROUPNAME:
# ------------
#  Confluence bin-installer automatically creates a 'confluence' user and a 'confluence' group. Just specify what it's name is.
ENV OS_GROUPNAME confluence

# CONFLUENCE_HOME:
# ---------------
# * This needs persistent storage. This can be mounted on a OS directory mount-point.
# * It needs to be owned by the OS user 'confluence'; UID 1000 normally.
# * The exact value to set for this variable can be found out by running the bin-installer manually in a test container.
# Note: confluence.home needs to be set to the value of ${CONFLUENCE_HOME}
#       in ${CONFLUENCE_INSTALL}/confluence/WEB-INF/classes/confluence-init.properties
#       However, the bin-installer takes care of that automatically.
ENV CONFLUENCE_HOME /var/atlassian/application-data/confluence

# CONFLUENCE_INSTALL:
# ------------------
# * Persistent storage is  not needed for these.
# * It is important to set this ENV var, because it is used in docker-entrypoint.sh
ENV CONFLUENCE_INSTALL /opt/atlassian/confluence

# TZ_FILE:
# -------
# This is the timezone file to use - by the container.
# Timezone files are normally found in /usr/share/zoneinfo/* .
# Set the path of the correct zone file you want to use for your container.
# Actual management of timezone is handled in the docker-entrypoint.sh,
#   but it is important for it to specidied in image, or passed to the container.
# TimeZone is set in a non-so-straightforward way, for certain reason.
ENV TZ_FILE "/usr/share/zoneinfo/Europe/Oslo"

# JAVA_HOME:
# ---------
# It is optional (but good) to set JAVA_HOME.
# If you configure it, ensure that it is the path to the directory where you find the bin/java under it.
ENV JAVA_HOME /opt/atlassian/confluence/jre

# JAVA_OPTS:
# ---------
# Optional values you want to pass as JAVA_OPTS. You can pass Java memory parameters to this variable,
#    but in newer versionso of Atlassian software, memory settings are done in CATALINA_OPTS.
# JAVA_OPTS  "-Dsome.javaSetting=somevalue"
# ENV JAVA_OPTS "-Dhttp.nonProxyHosts=confluence.example.com"

# CATALINA settings:
# -----------------
# CATLINA_OPTS will be used by CONFLUENCE_INSTALL/bin/setenv.sh script .
# You can use this to setup internationalization options and also any Java memory settings.
# It is a good idea to use same value for -Xms and -Xmx to avoid frequence shrinking and expanding of Java memory.
# In the example below it is set to 1 GB. It should always be half (or less) of physical RAM of the server/node/pod/container.
ENV CATALINA_OPTS "-Dfile.encoding=UTF-8 -Xms1024m -Xmx1024m"

# ENABLE_CERT_IMPORT:
# ------------------ 
# Allow import of user defined (self-signed) certificates.
ENV ENABLE_CERT_IMPORT false

# SSL_CERTS_PATH:
# --------------
# If you have self signed certificates, you need to force Atlassian applications to trust those certs.
#   This is very useful when different atlassian applications need to talk to each other over application links.
# This should be a path which you either volume-mount in docker or k8s.
ENV SSL_CERTS_PATH /var/atlassian/ssl

# DATACENTER_MODE:
# ----------------
# This needs to be set to true if you want to setup Confluence in a data-center mode, using multiple confluence instances. 
#   This can stay set as false, if you are running a standalone confluence (server) instance. 
#   This has no effect on the role of your confluence instance; which may be 'test' or 'production'.
ENV DATACENTER_MODE false

# CONFLUENCE_DATACENTER_SHARE:
# ---------------------------
# This is only used in DataCenter mode. It needs to be a shared location, which multiple confluence instances can write to.
# This location will most probably be an NFS share, and should exist on the file system.
# If it does not exist, then it will be created and chown to the confluence OS user.
# NB: FOr this to work, DATACENTER_MODE should be set to true.
# ENV CONFLUENCE_DATACENTER_SHARE /var/atlassian/confluence-datacenter
ENV CONFLUENCE_DATACENTER_SHARE /mnt/shared

# CLUSTER_PEER_IPS:
# ----------------
# Comma separated list of cluster peer IPs in datacenter mode.
# This is set automatically when run in Kuberenetes. No need to bother about it in Kubernetes.
# This 'needs' to be set if confluence is run on plain docker host in data-center mode. 
#   In that case, we need to pass it the IP addresses of the "peer" nodes - as ENV vars, 
#    and not the IP of this node itself.
# If you are running confluence as standalone, you don't need to bother about it.


# Reverse proxy specific variables:
# ================================

# X_PROXY_NAME:
# ------------
# The FQDN used by anyone accessing confluence from outside (i.e. The FQDN of the proxy server/ingress controller):
# ENV X_PROXY_NAME 'confluence.example.com'

# X_PROXY_PORT:
# ------------
# The public facing port, not the confluence container port
# ENV X_PROXY_PORT '443'

# X_PROXY_SCHEME:
# --------------
# The scheme used by the public facing proxy (normally https)
# ENV X_PROXY_SCHEME 'https'

# X_CONTEXT_PATH:
# --------------
# (formerly X_PATH)
# IMPORTANT: BREAKING CHANGE: This was formerly X_PATH. Please adjust your scripts/YAML/TOML files accordingly.
# The context path, if any. Best to leave disabled, or set to blank.
# ENV X_CONTEXT_PATH ''

#
#
####################################### END -  Environment variables #################################################



########################################### START - Build the image ###############################################
#
#


# The internationlization commands shown below are added in the main RUN section further below. So no need to uncomment them here.

# Internaltionalization / i18n - Notes on OS settings (Fedora):
# ------------------------------------------------------------
# Note the file '/etc/sysconfig/i18n' does not exist by default. 
# echo -e "LANG=\"en_US.UTF-8\" \n LC_ALL=\"en_US.UTF-8\"" > /etc/sysconfig/i18n
# echo -e "LANG=\"en_US.UTF-8\" \n LC_ALL=\"en_US.UTF-8\"" > /etc/locale.conf

# Internaltionalization / i18n - Notes on OS settings (Debian):
# ------------------------------------------------------------
# echo -e "LANG=\"en_US.UTF-8\" \n LC_ALL=\"en_US.UTF-8\"" > /etc/default/locale

# Unattended installation:
# ------------------------
# * Reference: https://confluence.atlassian.com/confluence064/installing-confluence-on-linux-720411834.html
# * Confluence response file is used for unattended installation using bin installer.
COPY confluence-response.varfile /tmp/

# We need the following in the container image:
# * xmlstarlet to modify XML files.
# * findutils provide 'find' ,which is helpful in finding files, especially during development and trouble-shooting.
# * gunzip, hostname , ps are  needed by installer.
# * 'which' is used by the installer to find the location of gunzip
# * iproute provides tools: ss/netstat for troubleshooting.
# * jq
# * graphviz was needed by a confluence plugin
# * change ownership of /etc/localtime to OS_USERNAME, so we can link to it in docker-entrypoint.sh
# * Download Confluence Software (bin-installer)
# * The bin-installer installs (bundled) Oracle Java automatically.
#     Link: https://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-${CONFLUENCE_VERSION}-x64.bin
# * The 'sync' below is silly but needed, so dockerhub can build the image correctly. Otherwise it occasionally fails.
# * After the installer is finished running, we fix some permissions, such as /opt/atlassian/*.
# ** This is needed because the installer runs as root and sets up those directories under root's ownership.
# The installer creats a user confluence.
# ** Later, we modify certain files inside the confluence_home, such as server.xml,
#       using our docker-entrypoint.sh script, which runs as user confluence (UID 1000).
# After the installer is finished running, we fix ownership and permissions, such as CONFLUENCE_INSTALL and CONFLUENCE_HOME.
# The silly syncs are for Dockerhub to process this properly.
# The fonts are added because AdoptJDK/JRE does not contain fonts and Confluence complaints about it.

RUN  echo -e "LANG=\"en_US.UTF-8\" \n LC_ALL=\"en_US.UTF-8\"" > /etc/sysconfig/i18n \
  && echo -e "LANG=\"en_US.UTF-8\" \n LC_ALL=\"en_US.UTF-8\"" > /etc/locale.conf \
  && yum -y install xmlstarlet findutils which gzip hostname procps iputils bind-utils iproute jq graphviz graphviz-gd dejavu-sans-fonts \
  && sync \
  && yum -y clean all \
  && ln -sf ${TZ_FILE} /etc/localtime \
  && echo "Downloading Confluence ${CONFLUENCE_VERSION}" \
  && curl -# -L -O https://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-${CONFLUENCE_VERSION}-x64.bin \
  && sync \
  && chmod +x ./atlassian-confluence-${CONFLUENCE_VERSION}-x64.bin \
  && sync \
  && ./atlassian-confluence-${CONFLUENCE_VERSION}-x64.bin -q -varfile /tmp/confluence-response.varfile \
  && sync \
  && echo -e "Confluence version: ${CONFLUENCE_VERSION} \n" > ${CONFLUENCE_INSTALL}/atlassian-version.txt \
  && sync \
  && ${CONFLUENCE_INSTALL}/jre/bin/java \
       -classpath ${CONFLUENCE_INSTALL}/lib/catalina.jar \
       org.apache.catalina.util.ServerInfo  >> ${CONFLUENCE_INSTALL}/atlassian-version.txt  \
  && sync \
  && rm -f ./atlassian-confluence-${CONFLUENCE_VERSION}-x64.bin \
  && if [ -n "${CONFLUENCE_DATACENTER_SHARE}" ] && [ ! -d "${CONFLUENCE_DATACENTER_SHARE}" ]; then mkdir -p ${CONFLUENCE_DATACENTER_SHARE}; fi \
  && if [ -n "${CONFLUENCE_DATACENTER_SHARE}" ] && [ -d "${CONFLUENCE_DATACENTER_SHARE}" ]; then chown -R ${OS_USERNAME}:${OS_GROUPNAME} ${CONFLUENCE_DATACENTER_SHARE}; fi \
  && chown -R ${OS_USERNAME}:${OS_GROUPNAME} ${CONFLUENCE_INSTALL} ${CONFLUENCE_HOME} \
  && HOME_DIR=$(grep ${OS_USERNAME} /etc/passwd | cut -d ':' -f 6) \
  && cp /etc/localtime ${HOME_DIR}/ \
  && chown ${OS_USERNAME}:${OS_GROUPNAME} ${HOME_DIR}/localtime \
  && ln -sf ${HOME_DIR}/localtime /etc/localtime \
  && sync \
  && if [ -n "${SSL_CERTS_PATH}" ] && [ ! -d "${SSL_CERTS_PATH}" ]; then mkdir -p ${SSL_CERTS_PATH}; fi \
  && if [ -n "${SSL_CERTS_PATH}" ] && [ -d "${SSL_CERTS_PATH}" ]; then chown ${OS_USERNAME}:${OS_GROUPNAME} ${SSL_CERTS_PATH}; fi \
  && sync

# PLUGINS_FILE (Confluence plugins):
# ----------------------------------
# Any additional confluence plugins you need to install should be listed in file named `confluence-plugins.list` - one at each line.
# Then mount that file at container runtime at the location specified you specify in PLUGINS_FILE environment variable.
# This also means that you can control the location and name of this file just by controlling this variable.
# The following is the path inside the container where the plugin file will be mounted.
ENV PLUGINS_FILE /tmp/confluence-plugins.list


# Copy docker-entrypoint.sh to configure server.xml configuration file in order to run the service behind a reverse proxy.
COPY docker-entrypoint.sh /

#
#
########################################### END - Build the image ###########################################

# Expose default HTTP connector port. For confluence it is 8090.
EXPOSE 8090/tcp

# Expose a separate HTTP connector port where synchrony connects.
# Required and valid only in DataCenter mode.
EXPOSE 8091/tcp

# Expose the additional connector's port (8888), if you enabled ADDITIONAL_CONNECTOR further up in this Dockerfile.
# If you are not using, it is best to not expose it as well.
# EXPOSE 8888/tcp

# Change the  the default working directory from '/' to '/var/atlassian/application-data/confluence'
#   - or whatever value you used above as CONFLUENCE_HOME.
WORKDIR ${CONFLUENCE_HOME}

# Set the default user for the image/container to user 'confluence'. Confluence software will be run as this user & group.
# USER confluence:confluence
USER ${OS_USERNAME}:${OS_GROUPNAME}

# Persistent volumes:
# Set volume mount points for home directory, because changes to the home directory needs to be persisted.
# Optionally, changes to parts of the installation directory also need persistence, eg. logs.
# VOLUME /var/atlassian/application-data/confluence
VOLUME ["${CONFLUENCE_HOME}", "${CONFLUENCE_INSTALL}/logs"]

# We have a custom entrypoint, which sets up server.xml with reverse proxy settings - if provided - and other stuff.
#  When ENTRYPOINT is present in a dockerfile, it is always run before executing CMD.
ENTRYPOINT ["/docker-entrypoint.sh"]

# Run Atlassian CONFLUENCE as a foreground process by default, using our modified startup script.
# The CMD command does not take environment variable, so it has to be a fixed path.
CMD ["/opt/atlassian/confluence/bin/start-confluence.sh", "-fg"]

# End of Dockerfile. Below are just some notes.
#
#
########################################### END - Build the image ###############################################

# Build this image manually:
# =========================
# docker build -t test/confluence-server:7.8.0-test .
# docker push test/confluence-server:7.8.0-test

# Check build-instructions.md for instructions for automated builds.
