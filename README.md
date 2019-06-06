# Atlassian Software in Kubernetes (ASK) - Confluence

![ASK-Logo](images/ask-logo.png)

This respository is a component of **[ASK](https://www.praqma.com/products/ask/) Atlassian Software in Kubernetes** ; and holds program-code to create Docker image for Confluence. 

Although the title says "Atlassian Software in Kubernetes", the container image can be run on plain Docker/Docker-Compose/Docker-Swarm, etc. 

This image can be used to run a single / stand-alone  instance of Confluence Software or a clustered setup known as Confluence DataCenter. You simply need to enable certain environment variables to get that done.

The source-code in this repository is released under MIT License, but the actual docker container images (binaries) built by it are not. You are free to use this source-code to build your own Confluence docker images and host them whereever you want. Please remember to consider various Atlassian and Oracle related lincense limitations when doing so.

## Description

- Uses Fedora 29 as base image.
- Uses Atlassian Confluence binary installer, which comes with built-in Oracle JDK - Adopt JDK/JRE in the newer installers.
- Exposes port 8090
- Supports data center mode and self signed certs.
- Can be setup behind a reverse proxy by setting up certain proxy related environment variables as mentioned below.


## Getting Started

### Build:
First, you need to build the container image.

```shell
docker build -t local/confluence:version-tag .
```

### Usage:
In it's simplest form, this image can be used by executing:

```shell
$ docker run -p 8090:8090 -d local/confluence:version-tag
```

If you want to set it up behind a reverse proxy, use the following command:

```shell
docker run \
  --name confluence \
  --publish 8090:8090 \
  --publish 8091:8091 \
  --env X_PROXY_NAME="confluence.example.com" \
  --env X_PROXY_PORT="8090" \
  --env X_PROXY_SCHEME="https" \
  --detach \
  praqma/confluence:6.15.4
```

**Note:** When setting up Confluence behind a (GCE/AWS/other) proxy/load balancer, make sure to setup proxy/load-balancer timeouts to large values such as 300 secs or more. (The default is set to 60 secs). It is **very** important to setup these timeouts, as Confluence (and other atlassian software) can take significant time setting up initial database. Smaller timeouts will panic Confluence setup process and it will terminate.

If you run without providing any exisiting database, CONFLUENCE will run and will present you with the web-setup wizard:

```shell
docker run \
  -p 8090:8090  \
  -d local/confluence:version-tag
```

If you want to use a different CONFLUENCE version, then simply change the version number in the Dockerfile, and rebuild the image.


## Certificates

Supply additional certificates from a single mounted directory.

```shell
docker run \
    --name confluence \
    --publish 8090:8090 \
    --publish 8091:8091 \
    --volume /path/to/certificates:/var/atlassian/ssl \
    --detach \
    owner/image:tag
```

See `SSL_CERTS_PATH` ENV variable in [Dockerfile](Dockerfile).

Similar output should be shown by `docker logs container-name`.

```text
Importing certificate: /var/atlassian/ssl/eastwind.crt ...
Certificate was added to keystore
Importing certificate: /var/atlassian/ssl/northwind.crt ...
Certificate was added to keystore
Importing certificate: /var/atlassian/ssl/southwind.pem ...
Certificate was added to keystore
Importing certificate: /var/atlassian/ssl/westwind.pem ...
Certificate was added to keystore
```

## User provided plugins:
If you want to add plugins of your choice, you can list their IDs in `confluence-plugins.list` file , one plugin at each line. You can volume-mount this file inside the container as `/tmp/confluence-plugins.list` . The `docker-entrypoint.sh` script will process this file and install the plugins. You can customize the location of this file in Dockerfile by setting the PLUGINS_FILE environment var to a different location.

```shell
docker run \
  -p 8090:8090  \
  -v ${PWD}/confluence-plugins.list:/tmp/confluence-plugins.list \
  -d local/confluence:version-tag
```

## Environment variables

The following environment variables can be set when building your docker image.


| Env name | Description                                                                                                                                                                                                                                                                                                        | Defaults                              |
|------------------------------ |------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------     |---------------------------------      |
| CONFLUENCE_VERSION                  | The version number which is part of the name of the confluence software bin/tarball/zip.                                                                                                                                                                                                                                    | 6.15.4                                 |
| DATACENTER_MODE               | This needs to be set to 'true' if you want to setup Confluence in a data-center mode. Need different lincense for this                                                                                                                                                                                                      | false                                 |
| CONFLUENCE_DATACENTER_SHARE         | It needs to be a shared location, which multiple confluence instances can write to. This location will most probably be an NFS share, and should exist on the file system.  If it does not exist, then it will be created and chown to the confluence OS user.  NB: For this to work, DATACENTER_MODE should be set to true.      | /var/atlassian/confluence-datacenter        |
| TZ_FILE                       | Timezone. Set the path of the correct zone you want to use for your container. Can be set at runtime as well                                                                                                                                                                                                          | /usr/share/zoneinfo/Europe/Oslo       |
| OS_USERNAME   | Confluence bin-installer automatically creates a 'confluence' user and a 'confluence' group. Just specify what it's name is. | confluence     |
| OS_GROUPNAME  | Confluence bin-installer automatically creates a 'confluence' user and a 'confluence' group. Just specify what it's name is. | confluence     |
| CONFLUENCE_HOME     | This is where run-time data will be saved. It needs persistent storage. This can be mounted on mount-point inside container. It needs to be owned by the same UID as of user confluence, normally UID 1000. The value if this variable should be same as 'app.confHome' in the confluence-response.varfile file. | /var/atlassian/application-data/confluence |
| CONFLUENCE_INSTALL  | This is where Confluence software will be installed. Persistent storage is NOT needed. The value if this variable should be same as 'sys.installationDir' in the confluence-response.varfile file. | /opt/atlassian/confluence |
| JAVA_OPTS | Optional values you want to pass as JAVA_OPTS. You can pass Java memory parameters to this variable, but in newer versionso of Atlassian software, memory settings are done in CATALINA_OPTS. |  |
| CATLINA_OPTS | CATALINA_OPTS will be used by CONFLUENCE_INSTALL/bin/setenv.sh script . You can use this to setup internationalization options, and also any Java memory settings. It is a good idea to use same value for -Xms and -Xmx to avoid frequence shrinking and expanding of Java memory. e.g. `CATALINA_OPTS "-Dfile.encoding=UTF-8 -Xms2048m -Xmx2048m"` . The memory values should always be half (or less) of physical RAM of the server/node/pod/container. |    |
| X_PROXY_NAME | The FQDN used by anyone accessing confluence from outside (i.e. The FQDN of the proxy server/ingress controller) | confluence.example.com |
| X_PROXY_PORT | The public facing port, not the confluence container port | `443` |
| X_PROXY_SCHEME | The scheme used by the public facing proxy - normally https. | `https` |
| X_CONTEXT_PATH | The context path, if any. Best to leave blank. (This was formerly X_PATH. ) | |


## Get newest version from Atlassian

You can use Curl and jq to get the latest version og download link for the installed used in this repository. It makes it easy when you need to build a newer image.
```
curl -s https://my.atlassian.com/download/feeds/current/confluence.json | sed 's\downloads(\\' | sed s'/.$//' | jq -r '.[] | select(.platform=="Unix") | "Url:" + .zipUrl, "Version:" + .version, "Edition:" + .edition'
```
Output :
```
Url:https://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-6.15.4-x64.bin
Version:6.15.4
Edition:Standard

```

## Linter

You can use a linter that analyze source code to flag programming errors, bugs, stylistic errors, and suspicious constructs. There is [dockerlinter](https://github.com/RedCoolBeans/dockerlint) , which does this quite easily.

### Installation
```
$ sudo npm install -g dockerlint
```

### Usage:
```
dockerlint Dockerfile
```

Above command will parse the file and notify you about any actual errors (such an omitted tag when : is set), and warn you about common pitfalls or bad idiom such as the common use case of ADD. In order to treat warnings as errors, use the -p flag.

